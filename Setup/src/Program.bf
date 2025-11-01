using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

using LibClang;
using Rune.CBindingGenerator;

namespace GObject_Introspection_Beef.Setup;

class Program
{
	append static String usrInclude = .(64);

	static StringView staticClass;
	static StringView dir;

	public static int Main(String[] args)
	{
#if BF_PLATFORM_WINDOWS
		usrInclude.Set("C:/msys64/ucrt64/include");
#else
		usrInclude.Set("/usr/include");
#endif
		while (!Directory.Exists(usrInclude))
		{
			Console.WriteLine("Unix include dir not found, have you install msys?");
			Console.Write("Enter path to unix include dir: ");
			Console.ReadLine(usrInclude..Clear());
		}

		while (!File.Exists(scope $"{usrInclude}/gobject-introspection-1.0/girepository.h"))
		{
			Console.WriteLine("Please install gobject-introspection package");
			Console.Write("Proceed when ready...");
			Console.Read();
		}

		CBindings.LibraryInfo library = scope .()
		{
			args = char8*[?](
				scope $"-I{usrInclude}",
				scope $"-I{usrInclude}/glib-2.0",
				scope $"-I{usrInclude}/gobject-introspection-1.0",
				scope $"-I{usrInclude}/../lib/glib-2.0/include",
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
				else if (spelling.StartsWith("g_irepository")) spelling.RemoveFromStart(3);
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
				if (dir.IsNull) return String.Equals(cursorFile, currentHeader);
				return StringView(cursorFile).StartsWith(dir);
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
		dir = scope $"{usrInclude}/gobject-introspection-1.0";
		CBindings.Generate(
			scope $"{usrInclude}/gobject-introspection-1.0/girepository.h",
			"../src/GIRepositiory.bf",
			"GIRepository", library, "GLib");
		staticClass = "GIRFFI";
		dir = null;
		CBindings.Generate(
			scope $"{usrInclude}/gobject-introspection-1.0/girffi.h",
			"../src/GIRFFI.bf",
			"GIRFFI", library, "GIRepository", "GLib");
		staticClass = "GLib";
		dir = scope $"{usrInclude}/glib-2.0";
		CBindings.Generate(
			scope $"{usrInclude}/glib-2.0/glib.h",
			"../src/GLib.bf",
			"GLib", library);
		return 0;
	}
}