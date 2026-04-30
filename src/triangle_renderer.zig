const std = @import("std");
const gem = @import("gem");
const ash = @import("ash");
const vk = ash.vk;

const vert_spv align(@alignOf(u32)) = @embedFile("vertex_shader").*;
const frag_spv align(@alignOf(u32)) = @embedFile("fragment_shader").*;
const vertices_json = @embedFile("triangle_vertices");

pub const TriangleInstance = extern struct {
    angle: f32,
    offset_x: f32,
    offset_y: f32,
    color_r: f32,
    color_g: f32,
    color_b: f32,
};

const push_constant_size: u32 = @sizeOf(TriangleInstance);

const BufferResource = struct {
    buffer: vk.Buffer = .null_handle,
    memory: vk.DeviceMemory = .null_handle,

    fn deinit(self: *BufferResource, device: vk.DeviceProxy) void {
        if (self.buffer != .null_handle) {
            device.destroyBuffer(self.buffer, null);
            self.buffer = .null_handle;
        }
        if (self.memory != .null_handle) {
            device.freeMemory(self.memory, null);
            self.memory = .null_handle;
        }
    }
};

pub const TriangleRenderer = struct {
    allocator: std.mem.Allocator,

    device: ?vk.DeviceProxy = null,

    vertex_buffer: BufferResource = .{},
    render_pass: vk.RenderPass = .null_handle,
    pipeline_layout: vk.PipelineLayout = .null_handle,
    pipeline: vk.Pipeline = .null_handle,
    framebuffers: []vk.Framebuffer = &.{},

    vertices: []f32 = &.{},
    instances: std.ArrayList(TriangleInstance) = .empty,

    once_built: bool = false,
    sized_built: bool = false,

    pub fn init(allocator: std.mem.Allocator) TriangleRenderer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TriangleRenderer) void {
        self.instances.deinit(self.allocator);
        if (self.vertices.len != 0) self.allocator.free(self.vertices);
    }

    pub fn loadResources(self: *TriangleRenderer) !void {
        const parsed = try std.json.parseFromSlice([]f32, self.allocator, vertices_json, .{});
        defer parsed.deinit();
        self.vertices = try self.allocator.dupe(f32, parsed.value);
    }

    pub fn reset(self: *TriangleRenderer) void {
        self.instances.clearRetainingCapacity();
    }

    pub fn setInstances(self: *TriangleRenderer, instances: []const TriangleInstance) !void {
        self.instances.clearRetainingCapacity();
        try self.instances.appendSlice(self.allocator, instances);
    }

    pub fn createOnce(self: *TriangleRenderer, session: *ash.Session) !void {
        const manager = &session.manager.?;
        const device = manager.device orelse return error.DeviceNotInitialized;
        self.device = device;

        self.vertex_buffer = try createVertexBuffer(manager, self.vertices);
        self.once_built = true;
    }

    pub fn destroyOnce(self: *TriangleRenderer) void {
        if (!self.once_built) return;
        const device = self.device orelse return;
        self.vertex_buffer.deinit(device);
        self.device = null;
        self.once_built = false;
    }

    pub fn createSized(self: *TriangleRenderer, session: *ash.Session, extent: vk.Extent2D) !void {
        _ = extent;
        const device = session.manager.?.device orelse return error.DeviceNotInitialized;
        const swapchain = &session.swapchain.?;

        self.render_pass = try createRenderPass(device, swapchain.surface_format.format);
        errdefer device.destroyRenderPass(self.render_pass, null);

        self.pipeline_layout = try device.createPipelineLayout(&.{
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 1,
            .p_push_constant_ranges = @ptrCast(&[_]vk.PushConstantRange{.{
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
                .offset = 0,
                .size = push_constant_size,
            }}),
        }, null);
        errdefer device.destroyPipelineLayout(self.pipeline_layout, null);

        self.pipeline = try createPipeline(
            device,
            self.pipeline_layout,
            self.render_pass,
            &vert_spv,
            &frag_spv,
        );
        errdefer device.destroyPipeline(self.pipeline, null);

        self.framebuffers = try createFramebuffers(
            self.allocator,
            device,
            swapchain,
            self.render_pass,
        );
        errdefer destroyFramebuffers(self.allocator, device, self.framebuffers);

        self.sized_built = true;
    }

    pub fn destroySized(self: *TriangleRenderer) void {
        if (!self.sized_built) return;
        const device = self.device orelse return;
        destroyFramebuffers(self.allocator, device, self.framebuffers);
        self.framebuffers = &.{};
        if (self.pipeline != .null_handle) {
            device.destroyPipeline(self.pipeline, null);
            self.pipeline = .null_handle;
        }
        if (self.pipeline_layout != .null_handle) {
            device.destroyPipelineLayout(self.pipeline_layout, null);
            self.pipeline_layout = .null_handle;
        }
        if (self.render_pass != .null_handle) {
            device.destroyRenderPass(self.render_pass, null);
            self.render_pass = .null_handle;
        }
        self.sized_built = false;
    }

    pub fn draw(self: *TriangleRenderer, session: *ash.Session, frame: *const ash.Frame) !void {
        const device = session.manager.?.device orelse return error.DeviceNotInitialized;

        const clear_value = vk.ClearValue{
            .color = .{ .float_32 = .{ 0.0, 0.0, 0.0, 1.0 } },
        };
        const viewport = vk.Viewport{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(frame.extent.width),
            .height = @floatFromInt(frame.extent.height),
            .min_depth = 0,
            .max_depth = 1,
        };
        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = frame.extent,
        };

        device.cmdBeginRenderPass(frame.cmd, &.{
            .render_pass = self.render_pass,
            .framebuffer = self.framebuffers[@intCast(frame.image_index)],
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = frame.extent,
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear_value),
        }, .@"inline");

        device.cmdBindPipeline(frame.cmd, .graphics, self.pipeline);
        device.cmdSetViewport(frame.cmd, 0, &.{viewport});
        device.cmdSetScissor(frame.cmd, 0, &.{scissor});

        const offsets = [_]vk.DeviceSize{0};
        device.cmdBindVertexBuffers(frame.cmd, 0, &.{self.vertex_buffer.buffer}, &offsets);

        for (self.instances.items) |*push| {
            device.cmdPushConstants(
                frame.cmd,
                self.pipeline_layout,
                .{ .vertex_bit = true, .fragment_bit = true },
                0,
                push_constant_size,
                push,
            );
            device.cmdDraw(frame.cmd, 3, 1, 0, 0);
        }

        device.cmdEndRenderPass(frame.cmd);
    }

    // -- gem.Renderer vtable adapter ------------------------------------------

    pub fn renderer(self: *TriangleRenderer) gem.Renderer {
        return .{ .ptr = self, .vtable = &renderer_vtable };
    }

    const renderer_vtable: gem.Renderer.VTable = .{
        .createOnce = createOnceAdapter,
        .createSized = createSizedAdapter,
        .destroySized = destroySizedAdapter,
        .destroyOnce = destroyOnceAdapter,
        .draw = drawAdapter,
    };

    fn createOnceAdapter(ptr: *anyopaque, session: *ash.Session) anyerror!void {
        const self: *TriangleRenderer = @ptrCast(@alignCast(ptr));
        return self.createOnce(session);
    }
    fn createSizedAdapter(ptr: *anyopaque, session: *ash.Session, extent: vk.Extent2D) anyerror!void {
        const self: *TriangleRenderer = @ptrCast(@alignCast(ptr));
        return self.createSized(session, extent);
    }
    fn destroySizedAdapter(ptr: *anyopaque) void {
        const self: *TriangleRenderer = @ptrCast(@alignCast(ptr));
        self.destroySized();
    }
    fn destroyOnceAdapter(ptr: *anyopaque) void {
        const self: *TriangleRenderer = @ptrCast(@alignCast(ptr));
        self.destroyOnce();
    }
    fn drawAdapter(ptr: *anyopaque, session: *ash.Session, frame: *const ash.Frame) anyerror!void {
        const self: *TriangleRenderer = @ptrCast(@alignCast(ptr));
        return self.draw(session, frame);
    }
};

fn createVertexBuffer(manager: *const ash.Manager, vertices: []const f32) !BufferResource {
    const device = manager.device orelse return error.DeviceNotInitialized;

    var result = BufferResource{};
    errdefer result.deinit(device);

    result.buffer = try device.createBuffer(&.{
        .size = vertices.len * @sizeOf(f32),
        .usage = .{ .vertex_buffer_bit = true },
        .sharing_mode = .exclusive,
    }, null);

    const requirements = device.getBufferMemoryRequirements(result.buffer);
    result.memory = try manager.allocate(requirements, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    });
    try device.bindBufferMemory(result.buffer, result.memory, 0);

    const mapped = try device.mapMemory(result.memory, 0, vk.WHOLE_SIZE, .{});
    defer device.unmapMemory(result.memory);

    const gpu_floats: [*]f32 = @ptrCast(@alignCast(mapped));
    @memcpy(gpu_floats[0..vertices.len], vertices);

    return result;
}

fn createRenderPass(device: vk.DeviceProxy, format: vk.Format) !vk.RenderPass {
    const color_attachment = vk.AttachmentDescription{
        .format = format,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .present_src_khr,
    };
    const color_attachment_ref = vk.AttachmentReference{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };
    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment_ref),
    };
    return try device.createRenderPass(&.{
        .attachment_count = 1,
        .p_attachments = @ptrCast(&color_attachment),
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);
}

fn createPipeline(
    device: vk.DeviceProxy,
    pipeline_layout: vk.PipelineLayout,
    render_pass: vk.RenderPass,
    vert_code: []const u8,
    frag_code: []const u8,
) !vk.Pipeline {
    const vert = try device.createShaderModule(&.{
        .code_size = vert_code.len,
        .p_code = @ptrCast(@alignCast(vert_code.ptr)),
    }, null);
    defer device.destroyShaderModule(vert, null);

    const frag = try device.createShaderModule(&.{
        .code_size = frag_code.len,
        .p_code = @ptrCast(@alignCast(frag_code.ptr)),
    }, null);
    defer device.destroyShaderModule(frag, null);

    const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
        .{ .stage = .{ .vertex_bit = true }, .module = vert, .p_name = "main" },
        .{ .stage = .{ .fragment_bit = true }, .module = frag, .p_name = "main" },
    };

    const binding_description = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = 3 * @sizeOf(f32),
        .input_rate = .vertex,
    };
    const attribute_descriptions = [_]vk.VertexInputAttributeDescription{
        .{ .binding = 0, .location = 0, .format = .r32g32b32_sfloat, .offset = 0 },
    };

    const vertex_input = vk.PipelineVertexInputStateCreateInfo{
        .vertex_binding_description_count = 1,
        .p_vertex_binding_descriptions = @ptrCast(&binding_description),
        .vertex_attribute_description_count = attribute_descriptions.len,
        .p_vertex_attribute_descriptions = &attribute_descriptions,
    };
    const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
        .topology = .triangle_list,
        .primitive_restart_enable = .false,
    };
    const viewport_state = vk.PipelineViewportStateCreateInfo{
        .viewport_count = 1,
        .p_viewports = undefined,
        .scissor_count = 1,
        .p_scissors = undefined,
    };
    const rasterization = vk.PipelineRasterizationStateCreateInfo{
        .depth_clamp_enable = .false,
        .rasterizer_discard_enable = .false,
        .polygon_mode = .fill,
        .cull_mode = .{},
        .front_face = .clockwise,
        .depth_bias_enable = .false,
        .depth_bias_constant_factor = 0,
        .depth_bias_clamp = 0,
        .depth_bias_slope_factor = 0,
        .line_width = 1,
    };
    const multisample = vk.PipelineMultisampleStateCreateInfo{
        .rasterization_samples = .{ .@"1_bit" = true },
        .sample_shading_enable = .false,
        .min_sample_shading = 1,
        .alpha_to_coverage_enable = .false,
        .alpha_to_one_enable = .false,
    };
    const color_blend_attachment = vk.PipelineColorBlendAttachmentState{
        .blend_enable = .false,
        .src_color_blend_factor = .one,
        .dst_color_blend_factor = .zero,
        .color_blend_op = .add,
        .src_alpha_blend_factor = .one,
        .dst_alpha_blend_factor = .zero,
        .alpha_blend_op = .add,
        .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
    };
    const color_blend = vk.PipelineColorBlendStateCreateInfo{
        .logic_op_enable = .false,
        .logic_op = .copy,
        .attachment_count = 1,
        .p_attachments = @ptrCast(&color_blend_attachment),
        .blend_constants = [_]f32{ 0, 0, 0, 0 },
    };
    const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };
    const dynamic_state = vk.PipelineDynamicStateCreateInfo{
        .dynamic_state_count = dynamic_states.len,
        .p_dynamic_states = &dynamic_states,
    };

    const create_info = vk.GraphicsPipelineCreateInfo{
        .stage_count = shader_stages.len,
        .p_stages = &shader_stages,
        .p_vertex_input_state = &vertex_input,
        .p_input_assembly_state = &input_assembly,
        .p_tessellation_state = null,
        .p_viewport_state = &viewport_state,
        .p_rasterization_state = &rasterization,
        .p_multisample_state = &multisample,
        .p_depth_stencil_state = null,
        .p_color_blend_state = &color_blend,
        .p_dynamic_state = &dynamic_state,
        .layout = pipeline_layout,
        .render_pass = render_pass,
        .subpass = 0,
        .base_pipeline_handle = .null_handle,
        .base_pipeline_index = -1,
    };

    var pipeline: vk.Pipeline = undefined;
    _ = try device.createGraphicsPipelines(.null_handle, &.{create_info}, null, (&pipeline)[0..1]);
    return pipeline;
}

fn createFramebuffers(
    allocator: std.mem.Allocator,
    device: vk.DeviceProxy,
    swapchain: *const ash.Swapchain,
    render_pass: vk.RenderPass,
) ![]vk.Framebuffer {
    const framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.swap_images.len);
    errdefer allocator.free(framebuffers);

    var created: usize = 0;
    errdefer for (framebuffers[0..created]) |framebuffer| {
        device.destroyFramebuffer(framebuffer, null);
    };

    for (swapchain.swap_images, 0..) |swap_image, index| {
        framebuffers[index] = try device.createFramebuffer(&.{
            .render_pass = render_pass,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&swap_image.view),
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
        created += 1;
    }
    return framebuffers;
}

fn destroyFramebuffers(allocator: std.mem.Allocator, device: vk.DeviceProxy, framebuffers: []vk.Framebuffer) void {
    for (framebuffers) |framebuffer| {
        device.destroyFramebuffer(framebuffer, null);
    }
    allocator.free(framebuffers);
}
