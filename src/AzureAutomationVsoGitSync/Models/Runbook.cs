using Orchestrator.GraphRunbook.Model;
using Orchestrator.GraphRunbook.Model.Serialization;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace AzureAutomationVsoGitSync.Models
{
    public class Runbook
    {
        public const string RUNBOOK_EXT_GRAPH = ".graphrunbook";
        public const string RUNBOOK_EXT_PS = ".ps1";

        private SortedRunbookDictionary _allRunbooks;

        public Runbook(SortedRunbookDictionary allRunbooks, string filePath, string fileUrl)
        {
            this._allRunbooks = allRunbooks;
            this.FilePath = filePath;
            this.FileUrl = fileUrl;
        }

        public string FilePath { get; set; }
        public string FileUrl { get; set; }

        public string Name { get { return GetRunbookName(FilePath); } }
        public string FileName { get { return GetRunbookFileName(FilePath); } }
        public string FileExtension { get { return GetRunbookFileExtension(FilePath); } }

        public static string GetRunbookName(string filePath)
        {
            return Path.GetFileNameWithoutExtension(filePath);
        }
        public static string GetRunbookFileName(string filePath)
        {
            return Path.GetFileName(filePath);
        }
        public static string GetRunbookFileExtension(string filePath)
        {
            return Path.GetExtension(filePath);
        }

        public RunbookType Type
        {
            get
            {
                if (FileExtension.ToLowerInvariant() == RUNBOOK_EXT_GRAPH.ToLowerInvariant())
                {
                    return RunbookType.Graph;
                }
                else
                {
                    var workflowDeclaration = File.ReadLines(this.FilePath)
                        .TakeWhile(x => Regex.IsMatch(x, string.Format(@"workflow\s+{0}", Name), RegexOptions.IgnoreCase))
                        //.Take(1)
                        ;
                    if (workflowDeclaration.Any())
                    {
                        return RunbookType.PowerShellWorkflow;
                    }
                    else
                    {
                        return RunbookType.PowerShell;
                    }
                }
            }
        }

        public override string ToString()
        {
            return this.Name;
        }

        public IEnumerable<Runbook> Parents
        {
            get
            {
                return this._allRunbooks.Values
                    .Where(x => x.Children.Contains(this));
            }
        }
        public IEnumerable<Runbook> Children { get { return this.ChildReferences.Distinct(new RunbookReferenceNameEqualityComparer()).Select(x => x.TargetRunbook); } }
        public IEnumerable<RunbookReference> ChildReferences
        {
            get
            {
                var isRunbookNameMatch = new Func<string, string, bool>((line, name) =>
                { /* todo: presumably not sufficient for all cases, but gets most of the way there. */
                    // match "name", " name", " name ", "name.ps1", ".\name.ps1"
                    // but not "myname", "test-name", "name-else"
                    var regex = string.Format(@"(^|{{|\.\\|\s+)({0})($|.ps1|\s+)", name);
                    return Regex.IsMatch(line, regex, RegexOptions.IgnoreCase | RegexOptions.Singleline);
                });

                switch (Type)
                {
                    case RunbookType.Graph:
                        { /* todo: refactor runbook & runbookReference so graphical instance props make more sense */
                            var runbook = RunbookSerializer.Deserialize(File.ReadAllText(FilePath));

                            var acts = runbook.Activities
                                .Where(x => this._allRunbooks
                                    .Keys.Where(y => !string.Equals(y, this.Name, StringComparison.InvariantCultureIgnoreCase))
                                    .Any(z => x.Name.Equals(z)));
                            foreach (var act in acts)
                            { /* todo rough pass until the UI is fixed (so graphs can be saved after dragging runbooks onto canvas. */
                                yield return new RunbookReference(this._allRunbooks, this, act.Name.ToString(), 0, null);
                            }

                            var scriptActs = runbook.Activities
                                .OfType<Orchestrator.GraphRunbook.Model.WorkflowScriptActivity>();
                            foreach (var sa in scriptActs)
                            {
                                var i = 0;
                                foreach (var line in new string[] { sa.Begin, sa.Process, sa.End })
                                {
                                    i++;
                                    foreach (var rb in this._allRunbooks.Keys.Where(x => !string.Equals(x, this.Name, StringComparison.InvariantCultureIgnoreCase)))
                                    {
                                        if (isRunbookNameMatch(line, rb))
                                        {
                                            yield return new RunbookReference(this._allRunbooks, this, rb, i, line);
                                        }
                                    }
                                }
                            }
                            break;
                        }
                    case RunbookType.PowerShell:
                    case RunbookType.PowerShellWorkflow:
                        {
                            var i = 0;
                            foreach (var line in File
                                .ReadLines(this.FilePath)
                                // skip empty & comment lines
                                .SkipWhile(x => string.IsNullOrWhiteSpace(x) || x.Trim().StartsWith("#")))
                            {
                                i++;
                                foreach (var rb in this._allRunbooks.Keys.Where(x => !string.Equals(x, this.Name, StringComparison.InvariantCultureIgnoreCase)))
                                {
                                    if (isRunbookNameMatch(line, rb))
                                    {
                                        yield return new RunbookReference(this._allRunbooks, this, rb, i, line);
                                    }
                                }
                            }
                            break;
                        }
                }
            }
        }
    }
}
