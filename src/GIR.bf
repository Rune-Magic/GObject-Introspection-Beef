using System;
using System.FFI;

namespace GIRepository;

static class GIR
{
}

namespace GIRFFI;

typealias ffi_cif = FFILIB.FFICIF;
typealias ffi_type = FFIType;
typealias ffi_closure = void*;

static class GIRFFI
{
}

namespace GLib;

typealias gint8  = int8;
typealias gint16 = int16;
typealias gint32 = int32;
typealias gint64 = int64;
typealias guint8  = uint8;
typealias guint16 = uint16;
typealias guint32 = uint32;
typealias guint64 = uint64;
typealias GPid = void*;

typealias gsize = uint;
typealias gssize = int;
typealias gintptr = int;
typealias guintptr = uint;
typealias goffset = int;
typealias GType = int;

struct tm;
struct GValue;
struct GClosure;
typealias GParamFlags = gint;
typealias GSignalFlags = gint;

static class GLib
{
	typealias time_t = TimeSpan;
}

static
{
	[NoShow, Comptime(ConstEval=true)]
	public static gint64 G_GINT64_CONSTANT(gint64 g) => g;

	[NoShow, Comptime(ConstEval=true)]
	public static guint64 G_GUINT64_CONSTANT(guint64 g) => g;
}
