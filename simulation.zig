const std = @import("std");
const Random = std.Random;
const ArrayList = std.ArrayList;

/// Person type in the simulation
const PersonType = enum(u8) {
    Normal = 0,
    Addict = 1,
    Recoverer = 2,
    Converter = 3,

    pub fn symbol(self: PersonType) u8 {
        return switch (self) {
            .Normal => 'N',
            .Addict => 'A',
            .Recoverer => 'R',
            .Converter => 'C',
        };
    }

    pub fn influence(self: PersonType) f32 {
        return switch (self) {
            .Normal => 1.0,
            .Addict => 1.0,
            .Recoverer => 3.0,
            .Converter => 3.0,
        };
    }

    pub fn isAddictType(self: PersonType) bool {
        return self == .Addict or self == .Converter;
    }

    pub fn isNormalType(self: PersonType) bool {
        return self == .Normal or self == .Recoverer;
    }
};

/// Simulation parameters
pub const SimParams = struct {
    grid_size: usize,
    generations: usize,
    initial_normal: f32,
    initial_addict: f32,
    initial_recoverer: f32,
    initial_converter: f32,
    special_promotion_rate: f32,
    seed: u64,

    pub fn validate(self: SimParams) !void {
        const sum = self.initial_normal + self.initial_addict + 
                    self.initial_recoverer + self.initial_converter;
        if (@abs(sum - 1.0) > 0.001) {
            return error.InvalidProbabilities;
        }
        if (self.grid_size == 0 or self.generations == 0) {
            return error.InvalidDimensions;
        }
    }
};

/// Statistics for a single generation
pub const GenerationStats = struct {
    generation: usize,
    normal_count: usize,
    addict_count: usize,
    recoverer_count: usize,
    converter_count: usize,

    pub fn total(self: GenerationStats) usize {
        return self.normal_count + self.addict_count + 
               self.recoverer_count + self.converter_count;
    }

    pub fn print(self: GenerationStats, writer: anytype) !void {
        const t = self.total();
        try writer.print("Gen {d:4}: N={d:5} ({d:5.2}%), A={d:5} ({d:5.2}%), " ++
                        "R={d:5} ({d:5.2}%), C={d:5} ({d:5.2}%)\n",
            .{
                self.generation,
                self.normal_count,
                @as(f32, @floatFromInt(self.normal_count)) * 100.0 / @as(f32, @floatFromInt(t)),
                self.addict_count,
                @as(f32, @floatFromInt(self.addict_count)) * 100.0 / @as(f32, @floatFromInt(t)),
                self.recoverer_count,
                @as(f32, @floatFromInt(self.recoverer_count)) * 100.0 / @as(f32, @floatFromInt(t)),
                self.converter_count,
                @as(f32, @floatFromInt(self.converter_count)) * 100.0 / @as(f32, @floatFromInt(t)),
            });
    }
};

/// The main simulation grid
pub const Grid = struct {
    cells: []PersonType,
    size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize) !Grid {
        const cells = try allocator.alloc(PersonType, size * size);
        return Grid{
            .cells = cells,
            .size = size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Grid) void {
        self.allocator.free(self.cells);
    }

    pub fn get(self: Grid, x: usize, y: usize) PersonType {
        return self.cells[y * self.size + x];
    }

    pub fn set(self: *Grid, x: usize, y: usize, person: PersonType) void {
        self.cells[y * self.size + x] = person;
    }

    /// Get neighbor coordinates with wrap-around (toroidal topology)
    fn wrapCoord(self: Grid, coord: isize) usize {
        const size_i: isize = @intCast(self.size);
        const wrapped = @mod(coord, size_i);
        return @intCast(wrapped);
    }

    /// Calculate the influence pressure from 8 neighbors
    pub fn calculatePressure(self: Grid, x: usize, y: usize) struct { addict: f32, normal: f32 } {
        var addict_pressure: f32 = 0.0;
        var normal_pressure: f32 = 0.0;

        const x_i: isize = @intCast(x);
        const y_i: isize = @intCast(y);

        // Check all 8 neighbors
        var dy: isize = -1;
        while (dy <= 1) : (dy += 1) {
            var dx: isize = -1;
            while (dx <= 1) : (dx += 1) {
                if (dx == 0 and dy == 0) continue; // Skip self

                const nx = self.wrapCoord(x_i + dx);
                const ny = self.wrapCoord(y_i + dy);
                const neighbor = self.get(nx, ny);
                const inf = neighbor.influence();

                if (neighbor.isAddictType()) {
                    addict_pressure += inf;
                } else {
                    normal_pressure += inf;
                }
            }
        }

        return .{ .addict = addict_pressure, .normal = normal_pressure };
    }

    /// Count statistics for current grid state
    pub fn countStats(self: Grid, generation: usize) GenerationStats {
        var stats = GenerationStats{
            .generation = generation,
            .normal_count = 0,
            .addict_count = 0,
            .recoverer_count = 0,
            .converter_count = 0,
        };

        for (self.cells) |cell| {
            switch (cell) {
                .Normal => stats.normal_count += 1,
                .Addict => stats.addict_count += 1,
                .Recoverer => stats.recoverer_count += 1,
                .Converter => stats.converter_count += 1,
            }
        }

        return stats;
    }

    /// Print the grid (useful for small grids)
    pub fn print(self: Grid, writer: anytype) !void {
        for (0..self.size) |y| {
            for (0..self.size) |x| {
                try writer.writeByte(self.get(x, y).symbol());
                try writer.writeByte(' ');
            }
            try writer.writeByte('\n');
        }
    }
};

/// The main simulation engine
pub const Simulation = struct {
    grid: Grid,
    next_grid: Grid,
    params: SimParams,
    rng: Random,
    history: ArrayList(GenerationStats),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, params: SimParams) !Simulation {
        try params.validate();

        const grid = try Grid.init(allocator, params.grid_size);
        const next_grid = try Grid.init(allocator, params.grid_size);
        const history = ArrayList(GenerationStats).init(allocator);

        var prng = std.Random.DefaultPrng.init(params.seed);
        const rng = prng.random();

        var sim = Simulation{
            .grid = grid,
            .next_grid = next_grid,
            .params = params,
            .rng = rng,
            .history = history,
            .allocator = allocator,
        };

        try sim.initializeGrid();
        return sim;
    }

    pub fn deinit(self: *Simulation) void {
        self.grid.deinit();
        self.next_grid.deinit();
        self.history.deinit();
    }

    /// Initialize grid with specified proportions
    fn initializeGrid(self: *Simulation) !void {
        for (0..self.params.grid_size) |y| {
            for (0..self.params.grid_size) |x| {
                const r = self.rng.float(f32);
                var person: PersonType = undefined;

                if (r < self.params.initial_normal) {
                    person = .Normal;
                } else if (r < self.params.initial_normal + self.params.initial_addict) {
                    person = .Addict;
                } else if (r < self.params.initial_normal + self.params.initial_addict + 
                              self.params.initial_recoverer) {
                    person = .Recoverer;
                } else {
                    person = .Converter;
                }

                self.grid.set(x, y, person);
            }
        }

        // Record initial state
        const initial_stats = self.grid.countStats(0);
        try self.history.append(initial_stats);
    }

    /// Determine next state for a single cell based on peer pressure
    fn calculateNextState(self: *Simulation, x: usize, y: usize) PersonType {
        const current = self.grid.get(x, y);
        const pressure = self.grid.calculatePressure(x, y);

        const epsilon: f32 = 0.0001;
        const total_pressure = pressure.addict + pressure.normal + epsilon;

        // Calculate transition probability based on current state
        const transition_prob = if (current.isAddictType())
            pressure.normal / total_pressure
        else
            pressure.addict / total_pressure;

        // Roll for transition
        if (self.rng.float(f32) < transition_prob) {
            // Transition is happening
            if (current.isAddictType()) {
                // Addict/Converter -> Normal/Recoverer
                if (self.rng.float(f32) < self.params.special_promotion_rate) {
                    return .Recoverer;
                } else {
                    return .Normal;
                }
            } else {
                // Normal/Recoverer -> Addict/Converter
                if (self.rng.float(f32) < self.params.special_promotion_rate) {
                    return .Converter;
                } else {
                    return .Addict;
                }
            }
        }

        // No transition
        return current;
    }

    /// Run a single generation (synchronous update)
    fn stepGeneration(self: *Simulation) void {
        // Calculate next state for all cells
        for (0..self.params.grid_size) |y| {
            for (0..self.params.grid_size) |x| {
                const next_state = self.calculateNextState(x, y);
                self.next_grid.set(x, y, next_state);
            }
        }

        // Swap grids
        const temp = self.grid;
        self.grid = self.next_grid;
        self.next_grid = temp;
    }

    /// Run the full simulation
    pub fn run(self: *Simulation) !void {
        for (1..self.params.generations + 1) |gen| {
            self.stepGeneration();
            const stats = self.grid.countStats(gen);
            try self.history.append(stats);
        }
    }

    /// Print summary statistics
    pub fn printSummary(self: *Simulation, writer: anytype) !void {
        try writer.writeAll("\n=== SIMULATION SUMMARY ===\n");
        try writer.print("Grid Size: {d}x{d}\n", .{ self.params.grid_size, self.params.grid_size });
        try writer.print("Generations: {d}\n", .{self.params.generations});
        try writer.print("Seed: {d}\n\n", .{self.params.seed});

        try writer.writeAll("Initial Distribution:\n");
        try writer.print("  Normal: {d:.1}%\n", .{self.params.initial_normal * 100.0});
        try writer.print("  Addict: {d:.1}%\n", .{self.params.initial_addict * 100.0});
        try writer.print("  Recoverer: {d:.1}%\n", .{self.params.initial_recoverer * 100.0});
        try writer.print("  Converter: {d:.1}%\n\n", .{self.params.initial_converter * 100.0});

        try writer.writeAll("=== GENERATION HISTORY ===\n");
        for (self.history.items) |stats| {
            try stats.print(writer);
        }

        try writer.writeAll("\n=== FINAL STATE ===\n");
        const final = self.history.items[self.history.items.len - 1];
        try final.print(writer);

        const initial = self.history.items[0];
        try writer.writeAll("\n=== CHANGE FROM INITIAL ===\n");
        try writer.print("Normal: {d} -> {d} ({d:+})\n", 
            .{ initial.normal_count, final.normal_count, 
               @as(i64, @intCast(final.normal_count)) - @as(i64, @intCast(initial.normal_count)) });
        try writer.print("Addict: {d} -> {d} ({d:+})\n", 
            .{ initial.addict_count, final.addict_count,
               @as(i64, @intCast(final.addict_count)) - @as(i64, @intCast(initial.addict_count)) });
        try writer.print("Recoverer: {d} -> {d} ({d:+})\n", 
            .{ initial.recoverer_count, final.recoverer_count,
               @as(i64, @intCast(final.recoverer_count)) - @as(i64, @intCast(initial.recoverer_count)) });
        try writer.print("Converter: {d} -> {d} ({d:+})\n", 
            .{ initial.converter_count, final.converter_count,
               @as(i64, @intCast(final.converter_count)) - @as(i64, @intCast(initial.converter_count)) });
    }

    /// Print final grid state (for visualization)
    pub fn printFinalGrid(self: *Simulation, writer: anytype) !void {
        try writer.writeAll("\n=== FINAL GRID ===\n");
        try self.grid.print(writer);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    // Example simulation parameters
    const params = SimParams{
        .grid_size = 50,
        .generations = 100,
        .initial_normal = 0.70,
        .initial_addict = 0.20,
        .initial_recoverer = 0.05,
        .initial_converter = 0.05,
        .special_promotion_rate = 0.05,
        .seed = 42,
    };

    try stdout.writeAll("Starting Peer Pressure Monte Carlo Simulation...\n");

    var sim = try Simulation.init(allocator, params);
    defer sim.deinit();

    try sim.run();
    try sim.printSummary(stdout);

    // Only print grid if it's reasonably small
    if (params.grid_size <= 20) {
        try sim.printFinalGrid(stdout);
    }

    try stdout.writeAll("\nSimulation complete!\n");
}
