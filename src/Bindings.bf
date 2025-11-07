using System;
using System.FFI;

namespace GObject.Introspection;

static class GIR
{
	public const String so =
#if BF_PLATFORM_WINDOWS
		"girepository-1.0.dll";
#else
		"libgirepository-1.0.so";
#endif
}

[CRepr] struct GValue
{
	public GType g_type;
	public Data[2] data;

	[Union, CRepr] public struct Data
	{
		public gint v_int;
		public guint v_uint;
		public glong v_long;
		public gulong v_ulong;
		public gint64 v_int64;
		public guint64 v_uint64;
		public gfloat v_float;
		public gdouble v_double;
		public gpointer v_pointer;
	}
}

typealias ffi_cif = FFILIB.FFICIF;
typealias ffi_type = FFIType;
typealias ffi_closure = void*;

static class GIRFFI
{
	public const String so = GIR.so;
}

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

struct tm;
typealias time_t = TimeSpan;

static class GLib
{
	public const String so =
#if BF_PLATFORM_WINDOWS
	"glib-2.0.dll";
#else
	"libglib-2.0.so";
#endif
}

static
{
	[NoShow, Comptime(ConstEval=true)]
	public static gint64 G_GINT64_CONSTANT(gint64 g) => g;

	[NoShow, Comptime(ConstEval=true)]
	public static guint64 G_GUINT64_CONSTANT(guint64 g) => g;
}

extension GObject
{
	public const String so =
#if BF_PLATFORM_WINDOWS
	"gobject-2.0.dll";
#else
	"libgobject-2.0.so";
#endif
}
