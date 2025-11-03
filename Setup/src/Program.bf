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
	append static String dir = .(64);

	static Dictionary<String, String> prettyPaths = new .(64) ~ DeleteDictionaryAndKeysAndValues!(_);
	static List<String> classes = new .(64) ~ DeleteContainerAndItems!(_);

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
				if (cursor.kind == .StructDecl && spelling[0] == 'G')
				{
					classes.Add(new .(spelling));
					return null;
				}
				if (cursor.kind != .FunctionDecl || spelling[0] != 'g') return null;
				String withoutUnderscores = scope .(spelling.Length);
				for (let c in spelling)
					if (c != '_')
						withoutUnderscores.Append(c);
				for (let clas in classes.Reversed)
					if (withoutUnderscores.StartsWith(clas, .OrdinalIgnoreCase))
						return clas;
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
				for (let clas in classes.Reversed)
					if (spelling.StartsWith(clas, .OrdinalIgnoreCase))
					{
						spelling.RemoveFromStart(clas.Length);
						return;
					}
				if (spelling.StartsWith(staticClass))
					spelling.RemoveFromStart(staticClass.Length);
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
				if (dir.IsEmpty) return String.Equals(cursorFile, currentHeader);
				StringView file = .(cursorFile);
				String prettyPath;
				if (!prettyPaths.TryGetValueAlt(file, out prettyPath))
				{
					prettyPath = Path.GetActualPathName(file, ..new .(64));
					prettyPaths.Add(new .(file), prettyPath);
				}
				return prettyPath.StartsWith(dir);
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
				if (staticClass == "GObject")
					return cursor.kind == .MacroDefinition || spelling == "_GValue" || spelling == "GValue" ||
						(isOpaque && !StringView[?](
							"_GTypeCValue", "_GTypePlugin", "_GParamSpecPool", "_GBinding", "_GBindingGroup", "_GSignalGroup"
						).Contains(spelling));
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
		StringView outputNamespace = "GObject.Introspection";
		staticClass = "GIR";
		Path.GetActualPathName(scope $"{usrInclude}/gobject-introspection-1.0", dir..Clear());
		CBindings.Generate(
			scope $"{usrInclude}/gobject-introspection-1.0/girepository.h",
			"../src/GIRepositiory.bf",
			outputNamespace, library);
		staticClass = "GIRFFI";
		dir.Set(.Empty);
		CBindings.Generate(
			scope $"{usrInclude}/gobject-introspection-1.0/girffi.h",
			"../src/GIRFFI.bf",
			outputNamespace, library, "GIRepository", "GLib");
		staticClass = "GLib";
		Path.GetActualPathName(scope $"{usrInclude}/glib-2.0/glib", dir..Clear());
		CBindings.Generate(
			scope $"{usrInclude}/glib-2.0/glib.h",
			"../src/GLib.bf",
			outputNamespace, library);
		staticClass = "GObject";
		Path.GetActualPathName(scope $"{usrInclude}/glib-2.0/gobject", dir..Clear());
		CBindings.Generate(
			scope $"{usrInclude}/glib-2.0/glib-object.h",
			"../src/GObject.bf",
			outputNamespace, library);
		return 0;
	}
}