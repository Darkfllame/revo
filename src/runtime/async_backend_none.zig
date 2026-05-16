const async_backend = @import("./async_backend.zig");

pub fn submit(_: *async_backend.AsyncBackend, _: *anyopaque, _: *async_backend.AsyncJob) anyerror!async_backend.AsyncTicket {
    return error.OsNotSupported;
}

pub fn poll_all(_: *anyopaque, _: i32) anyerror!bool {
    return false;
}
