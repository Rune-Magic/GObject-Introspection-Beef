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

	[CLink] static extern int32 system(char8*);

	public static int Main(String[] args)
	{
		const String pkgConfig 
#if BF_PLATFORM_WINDOWS
			= @".\WinGTK4\bin\pkg-config.exe";
		{
			File.Delete("WinGTK4.json");
			var command = "wget -O WinGTK4.json https://api.github.com/repos/wingtk/gvsbuild/releases/latest";
			Runtime.Assert(system(command) == 0);

			/*var tagOutput = File.ReadAllText("WinGTK4.json", ..scope .());
			var startIndex = tagOutput.IndexOf("\"tag_name\":");
			StringView tag = tagOutput[startIndex...]
				..RemoveFromStart("\"tag_name\":".Length)
				..TrimStart()
				..TrimStart('"');
			tag = tag[..<tag.IndexOf('"')];
			var url = scope $"https://github.com/wingtk/gvsbuild/releases/download/{tag}/GTK4_Gvsbuild_{tag}_x64.zip";
			Console.WriteLine($"Downloading GTK4_Gvsbuild_{tag}_x64.zip, this may take a while");
			var downloadCommand = scope $"wget -O WinGTK4.zip {url}";
			File.Delete("WinGTK4.zip");
			Runtime.Assert(system(downloadCommand) == 0);*/

			Directory.CreateDirectory("WinGTK4");
			if (system("7z -version") == 0)
			{
				Runtime.Assert (system("7z x WinGTK4.zip -oWinGTK4 -y") == 0);
			}
			else
			{
				Console.WriteLine("7z not found, install it for faster extracting speeds");
				Console.WriteLine("Extracting using tar, this may take a while...");
				//Runtime.Assert(system("tar -xf WinGTK4.zip -C WinGTK4 -P") == 0);
			}
		}
#else
			= "pkg-config";

		mixin RequirePackage(String package)
		{
			while (system(scope $"{pkgConfig} {package}") != 0)
			{
				Console.Write($"Please install {package}...");
				Console.Read();
			}
		}

		RequirePackage!("pkg-config");
		RequirePackage!("gtk4");
		RequirePackage!("gobject-introspection-1.0");
#endif

		Runtime.Assert(system(pkgConfig + " --libs gobject-introspection-1.0 > libs.txt") == 0);
		Runtime.Assert(system(pkgConfig + " --cflags gobject-introspection-1.0 > cflags.txt") == 0);

		String cflagsStr = File.ReadAllText("cflags.txt", ..scope .(512));
		cflagsStr.Append('\0');
		List<char8*> cflags = scope .(16);
		for (let flag in cflagsStr.Split(' '))
		{
			flag.Ptr[flag.Length] = '\0';
			cflags.Add(flag.Ptr);
		}

		{
			String libs = File.ReadAllText("libs.txt", ..scope .(512));
			String libNamesWindows = scope .(256), libNamesUnix = scope .(256);
#if BF_PLATFORM_WINDOWS
			List<StringView> libDirs = scope .(8);
			for (var flag in libs.Split(' '))
			{
				if (!flag.StartsWith("-L")) continue;
				flag.RemoveFromStart(2);
				if (flag.EndsWith("../lib") || flag.EndsWith("..\\lib"))
					flag.RemoveFromEnd("/../lib".Length);
				libDirs.Add(flag);
			}
			String copyPaths = scope .(256);
#endif
			for (var flag in libs.Split(' '))
			{
				if (!flag.StartsWith("-l")) continue;
				flag.RemoveFromStart(2);
				if (!libNamesWindows.IsEmpty) libNamesWindows.Append(';');
				libNamesWindows.Append(flag, ".lib");
				if (!libNamesUnix.IsEmpty) libNamesUnix.Append(';');
				libNamesUnix.Append("lib", flag, ".a");
#if BF_PLATFORM_WINDOWS
				for (let dir in libDirs)
					for (let file in Directory.EnumerateFiles(dir))
					{
						String fileName = file.GetFileName(..scope .(64));
						if (!fileName.Contains(flag)) continue;
						copyPaths.Append("CopyToDependents(");
						let filePath = file.GetFilePath(..scope .(256));
						filePath.Quote(copyPaths);
						copyPaths.Append(")\n");
					}
#endif
			}
#if BF_PLATFORM_WINDOWS
			File.WriteAllText("../copy.script", copyPaths);
#endif
		}

		CBindings.LibraryInfo library = scope .()
		{
			args = cflags,
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
				else if (spelling.StartsWith('G'))
					spelling.RemoveFromStart(1);
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

		void Package(StringView header, StringView outputFile, StringView block, StringView directory = "")
		{
			staticClass = block;
			String headerPath = scope .(64);
			dir.Clear();
			String fileNameBuffer = scope .(64);
			findFile: do
			{
				for (var flag in cflagsStr.Split('\0'))
				{
					if (!flag.StartsWith("-I")) continue;
					flag.RemoveFromStart(2);
					for (let file in Directory.EnumerateFiles(flag))
					{
						file.GetFileName(fileNameBuffer..Clear());
						if (header != fileNameBuffer) continue;
						file.GetFilePath(headerPath);
						if (directory != "<none>")
							Path.GetActualPathName(scope $"{flag}/{directory}", dir);
						break findFile;
					}
				}
				Runtime.FatalError(scope $"Failed to find header: {header}");
			}
			library.customLinkage = scope $"Import({block}.so)";
			CBindings.Generate(headerPath, outputFile, "GObject.Introspection", library);
		}

		Package("girepository.h", "../src/GIRepository.bf", "GIR");
		Package("girffi.h", "../src/GIRFFI.bf", "GIRFFI", "<none>");
		Package("glib.h", "../src/GLib.bf", "GLib", "glib");
		Package("glib-object.h", "../src/GObject.bf", "GObject", "gobject");
		return 0;
	}
}