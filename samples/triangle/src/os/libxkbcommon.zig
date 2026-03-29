const c = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
});
pub const xkbctx :c.xkb_context = c.xkb_context_new(c.XKB_CONTEXT_NO_FLAGS);

