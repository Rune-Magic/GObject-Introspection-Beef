using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

using LibClang;
using Rune.CBindingGenerator;

namespace GObject_Introspection_Beef.Setup;

class Program
{
	const let usrInclude = "C:/msys64/ucrt64/include";

	static StringView staticClass;

	public static int Main(String[] args)
	{
		CBindings.LibraryInfo library = scope .()
		{
			args = char8*[?](
				String.ConstF($"-I{usrInclude}"),
				String.ConstF($"-I{usrInclude}/glib-2.0"),
				String.ConstF($"-I{usrInclude}/gobject-introspection-1.0"),
				String.ConstF($"-I{usrInclude}/../lib/glib-2.0/include"),
				"-D__GLIB_H_INSIDE__"
			),
			getBlock = scope (cursor, spelling) =>
			{
				if (cursor.kind != .FunctionDecl || spelling[0] != 'g') return null;
				return staticClass;
			},
			modifySourceName = scope (cursor, spelling, strBuffer) =>
			{
				strBuffer = null;
				if (cursor.kind != .FunctionDecl)
				{
					spelling.TrimStart('_');
					return;
				}
				if (spelling.StartsWith("g_ir_")) spelling.RemoveFromStart(5);
				else if (spelling.StartsWith("g_i")) spelling.RemoveFromStart(3);
				else if (spelling.StartsWith("g_")) spelling.RemoveFromStart(2);
				bool upper = true;
				strBuffer = new .(spelling.Length);
				for (let c in spelling)
				{
					if (c == '_') upper = true;
					else
					{
						strBuffer.Append(upper ? c.ToUpper : c);
						upper = false;
					}
				}
				spelling = strBuffer;
			},
			modifyEnumCaseSpelling = scope (spelling, parentSpelling, strBuffer) =>
			{
				int parentIdx = 0, spellingIdx = 0;
				while (spellingIdx < spelling.Length)
				{
					let c = spelling[spellingIdx++];
					if (c == '_') continue;
					if (parentIdx >= parentSpelling.Length) break;
					if (c.ToLower != parentSpelling[parentIdx++].ToLower) break;
				}
				spelling.RemoveFromStart(spellingIdx-1);
				bool upper = true;
				strBuffer = new .(spelling.Length);
				for (let c in spelling)
				{
					if (c == '_') upper = true;
					else
					{
						strBuffer.Append(upper ? c : c.ToLower);
						upper = false;
					}
				}
				if (strBuffer[0].IsDigit)
					strBuffer.Insert(0, '_');
				spelling = strBuffer;
			},
			includeCursorFromFile = scope (cursorFile, currentHeader) =>
			{
				return StringView(cursorFile).StartsWith(usrInclude + "/gobject-introspection-1.0");
			},
			isBlackListed = scope (cursor, spelling) =>
			{
				bool isOpaque = (cursor.kind == .StructDecl || cursor.kind == .UnionDecl) && CBindings.IsStructOpaque(cursor);
				if (staticClass == "GLib")
					return cursor.kind == .MacroDefinition ||
						(isOpaque && !StringView[?](
							"_GTimeZone", "_GDateTime", "_GBookmarkFile", "_GData", "_GKeyFile", "_GMappedFile",
							"_GVariant", "_GOptionContext", "_GOptionGroup", "_GTree", "_GTreeNode", "_GDir",
							"_GBytes", "_GAsyncQueue", "_GMarkupParseContext", "_GChecksum", "_GHashTable", 
							"_GHmac", "_GMainContext", "_GVariantType", "_GRegex", "_GMatchInfo", "_GSequence",
							"_GRand", "_GStringChunk", "_GStrvBuilder", "_GTimer", "_GMemChunk", "_GAllocator", 
							"_GValue", "_GSourcePrivate", "_GMainLoop", "_GPatternSpec", "GTestSuite", "GTestCase",
							"_GSequenceNode", "_GRelation", "_GCache", "_GUri"
						).Contains(spelling));
				if (staticClass == "GIR")
					return (cursor.kind == .MacroDefinition && !spelling.EndsWith("_VERSION")) ||
						(!isOpaque && spelling.StartsWith("_GIRepository"));
				return isOpaque;
			},
			handleTopLevelCursor = scope (cursor, unit, spelling, output, block) =>
			{
				output = null;
				block = "";
				if (cursor.kind != .TypedefDecl || !spelling.StartsWith("GI")) return .Continue;
				StringView type = .(CBindings.GetString!(Clang.GetTypeSpelling(Clang.GetTypedefDeclUnderlyingType(cursor))));
				if (type != "GIBaseInfo") return .Continue;
				output = new $"struct {spelling} : GIBaseInfo;\n";
				return .Skip;
			},
			isHandleUnderlyingOpaque = scope (type, spelling, typedefSpelling) =>
				typedefSpelling == "GIConv"
		};
		staticClass = "GIR";
		CBindings.Generate(
			usrInclude + "/gobject-introspection-1.0/girepository.h",
			"../src/GIRepositiory.bf",
			"GIRepository", library, "GLib");
		library.includeCursorFromFile = null;
		staticClass = "GIRFFI";
		CBindings.Generate(
			usrInclude + "/gobject-introspection-1.0/girffi.h",
			"../src/GIRFFI.bf",
			"GIRFFI", library, "GIRepository", "GLib");
		library.includeCursorFromFile = scope (cursorFile, currentHeader) =>
		{
			return StringView(cursorFile).StartsWith(usrInclude + "/glib-2.0");
		};
		staticClass = "GLib";
		CBindings.Generate(
			usrInclude + "/glib-2.0/glib.h",
			"../src/GLib.bf",
			"GLib", library);
		return 0;
	}
}