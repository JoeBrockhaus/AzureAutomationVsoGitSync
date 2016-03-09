using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AzureAutomationVsoGitSync.Models
{
    public class RunbookReference
    {
        private SortedRunbookCollection _allRunbooks;
        public RunbookReference(SortedRunbookCollection allRunbooks, Runbook sourceRunbook, string runbookName, int lineNumber, string lineContent)
        {
            this._allRunbooks = allRunbooks;
            this.SourceRunbook = sourceRunbook;
            this.TargetRunbookName = runbookName;
            this.LineNumber = lineNumber;
            this.LineContent = lineContent;
        }

        public string TargetRunbookName { get; set; }
        public int LineNumber { get; set; }
        public string LineContent { get; set; }

        public override string ToString()
        {
            return string.Format("{0}.{1}", this.SourceRunbook.Name, this.TargetRunbookName);
        }

        public Runbook SourceRunbook { get; private set; }
        public Runbook TargetRunbook { get { return this._allRunbooks.Find(this.TargetRunbookName); } }

    }

    public class RunbookReferenceNameComparer : IComparer<RunbookReference>
    {
        public int Compare(RunbookReference x, RunbookReference y)
        {
            return string.Compare(x.ToString(), y.ToString());
        }
    }
    public class RunbookReferenceNameEqualityComparer : IEqualityComparer<RunbookReference>
    {
        public bool Equals(RunbookReference x, RunbookReference y)
        {
            return (new RunbookReferenceNameComparer()).Compare(x, y) == 0;
        }

        public int GetHashCode(RunbookReference obj)
        {
            return obj.ToString().GetHashCode();
        }
    }
}
