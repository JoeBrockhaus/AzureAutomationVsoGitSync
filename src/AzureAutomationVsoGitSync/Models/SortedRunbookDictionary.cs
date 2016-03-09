
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AzureAutomationVsoGitSync.Models
{
    public class SortedRunbookCollection
    {
        private Dictionary<string, Runbook> _runbooks = new Dictionary<string, Runbook>();

        public IEnumerable<string> Keys { get { return this._runbooks.Keys; } }
        public IEnumerable<Runbook> Values { get { return this._runbooks.Values; } }

        public Runbook Add(string filePath, string fileUrl)
        {
            var rValue = new Runbook(this, filePath, fileUrl);
            this._runbooks.Add(rValue.Name, rValue);
            return rValue;
        }

        public Runbook Find(string name)
        {
            return this._runbooks.ContainsKey(name)
                ? this._runbooks[name]
                : null;
        }
        public Runbook FindByUrl(string url)
        {
            return this._runbooks
                .FirstOrDefault(x => x.Value.FileUrl.Equals(url, StringComparison.InvariantCultureIgnoreCase))
                .Value;
        }
        public Runbook this[string key] { get { return this._runbooks[key]; } }

        public IEnumerable<Runbook> Result
        {
            get
            {
                return this._runbooks.Values
                    .TSort(x =>
                        x.Children,
                        throwOnCycle: true);
            }
        }
    }
}
