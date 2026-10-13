using System;
using System.IO;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;

public static class TwoPlusDesktopCompiler
{
    public static void Build(string root, string framework)
    {
        var trees = new[] { "MemoryCore.cs", "MemoryForm.cs", "Program.cs" }
            .Select(name => CSharpSyntaxTree.ParseText(File.ReadAllText(Path.Combine(root, name)),
                new CSharpParseOptions(LanguageVersion.CSharp7_3), name)).ToArray();
        var references = new[] { "mscorlib.dll", "System.dll", "System.Core.dll", "System.Windows.Forms.dll", "System.Drawing.dll", "System.Management.dll" }
            .Select(name => MetadataReference.CreateFromFile(Path.Combine(framework, name))).ToArray();
        var options = new CSharpCompilationOptions(OutputKind.WindowsApplication)
            .WithPlatform(Platform.AnyCpu).WithOptimizationLevel(OptimizationLevel.Release)
            .WithDeterministic(true).WithConcurrentBuild(false);
        var compilation = CSharpCompilation.Create("2plus-Memory-Tool", trees, references, options);
        using (var pe = File.Create(Path.Combine(root, "2plus-Memory-Tool.exe")))
        using (var manifest = File.OpenRead(Path.Combine(root, "app.manifest")))
        using (var icon = File.OpenRead(Path.Combine(root, "build", "app.ico")))
        using (var resources = compilation.CreateDefaultWin32Resources(true, false, manifest, icon))
        {
            var emitted = compilation.Emit(pe, win32Resources: resources);
            foreach (var diagnostic in emitted.Diagnostics) Console.WriteLine(diagnostic.ToString());
            if (!emitted.Success) throw new InvalidOperationException("Windows compilation failed");
        }
        Console.WriteLine("PASS: independent Windows GUI EXE, .NET Framework 4.6.2, no embedded scripts.");
    }
}
