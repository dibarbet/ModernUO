// See https://aka.ms/new-console-template for more information
using Microsoft.Build.Locator;
using Microsoft.CodeAnalysis.MSBuild;

Console.WriteLine("Hello, World!");

MSBuildLocator.RegisterDefaults();

var workspace = MSBuildWorkspace.Create();

workspace.WorkspaceFailed += (sender, args) =>
{
    Console.WriteLine(args.Diagnostic.Message);
};

var slnPath = args[0];
Console.WriteLine($"Opening solution {slnPath}");

var solution = await workspace.OpenSolutionAsync(slnPath, new Progress());

foreach(var project in solution.Projects)
{
    Console.WriteLine($"Project {project.Name} has {project.Documents.Count()} documents");
}


class Progress : IProgress<ProjectLoadProgress>
{
    public void Report(ProjectLoadProgress value)
    {
        Console.WriteLine($"{value.Operation} completed for {value.FilePath} ({value.TargetFramework}) in {value.ElapsedTime}ms");
    }
}   
