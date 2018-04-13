﻿// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//  
//    http://www.apache.org/licenses/LICENSE-2.0
//   
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System.Collections.Generic;
using System.Linq;
using LibGit2Sharp;

namespace Git.Automation
{
    public sealed class TagInfo
    {
        public TagInfo(Tag tag)
        {
            Name = tag.FriendlyName;
            CanonicalName = tag.CanonicalName;
            Target = tag.Target.Id;
        }

        public string Name { get; private set; }
        public string CanonicalName { get; private set; }
        public ObjectId Target { get; private set; }

        public string Sha
        {
            get { return Target.Sha; }
        }
    }
}