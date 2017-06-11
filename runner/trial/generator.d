module trial.generator;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import std.conv;

import dub.internal.vibecompat.core.log;

import trial.settings;

string generateTestFile(Settings settings, bool hasTrialDependency, string[] modules, string[] externalModules, string testName = "") {
  testName = testName.replace(`"`, `\"`);

  if(testName != "") {
    logInfo("Selecting tests conaining `" ~ testName ~ "`.");
  }

  enum d =
    import("discovery/unit.d") ~
    import("runner.d") ~
    import("interfaces.d") ~
    import("settings.d") ~
    import("step.d") ~
    import("executor/parallel.d") ~
    import("executor/single.d") ~

    import("reporters/writer.d") ~
    import("reporters/result.d") ~
    import("reporters/stats.d") ~
    import("reporters/dotmatrix.d") ~
    import("reporters/html.d") ~
    import("reporters/landing.d") ~
    import("reporters/list.d") ~
    import("reporters/progress.d") ~
    import("reporters/specprogress.d") ~
    import("reporters/specsteps.d") ~
    import("reporters/spec.d");

  string code;

  if(hasTrialDependency) {
    writeln("We are using the project `trial:lifecicle` dependency.");

    code = "
      import trial.discovery.unit;
      import trial.runner;
      import trial.interfaces;
      import trial.settings;
      import trial.stackresult;
      import trial.reporters.result;
      import trial.reporters.stats;
      import trial.reporters.spec;\n";
  } else {
    writeln("We will embed the `trial:lifecicle` code inside the project.");

    code = "version = is_trial_embeded;\n" ~ d.split("\n")
            .filter!(a => !a.startsWith("module"))
            .filter!(a => !a.startsWith("@(\""))
            .filter!(a => a.indexOf("import") == -1 || a.indexOf("trial.") == -1)
            .join("\n")
            .removeUnittests;
  }

  code ~= `
  void main() {
      setupLifecycle(` ~ settings.toCode ~ `);
      auto testDiscovery = new UnitTestDiscovery();` ~ "\n\n";

  if(hasTrialDependency) {
    externalModules ~= [ "_d_assert", "std.", "core." ];

    code~= `
      StackResult.externalModules = ` ~ externalModules.to!string ~ `;
    `;
  }

  code ~= modules
    .map!(a => `      testDiscovery.addModule!"` ~ a ~ `";`)
    .join("\n");

  code ~= `
      LifeCycleListeners.instance.add(testDiscovery);
      runTests("` ~ testName ~ `");
  }

  version (unittest) shared static this()
  {
      import core.runtime;
      Runtime.moduleUnitTester = () => true;
  }`;

  return code;
}

version(unittest) {
  import std.datetime;
  import fluent.asserts;
}

string removeTest(string data) {
  auto cnt = 0;

  if(data[0] == ')') {
    return "unittest" ~ data;
  }

  if(data[0] != '{') {
    return data;
  }

  foreach(size_t i, ch; data) {
    if(ch == '{') {
      cnt++;
    }

    if(ch == '}') {
      cnt--;
    }

    if(cnt == 0) {
      return data[i+1..$];
    }
  }

  return data;
}

string removeUnittests(string data) {
  auto pieces = data.split("unittest");

  return pieces
          .map!(a => a.strip.removeTest)
          .join("\n")
          .split("version(\nunittest)")
          .map!(a => a.strip.removeTest)
          .join("\n")
          .split("version (\nunittest)")
          .map!(a => a.strip.removeTest)
          .join("\n")
          .split("\n")
          .map!(a => a.stripRight)
          .join("\n");
}

@("It should remove unit tests")
unittest{
  `module test;

  @("It should find this test")
  unittest
  {
    import trial.discovery;
    {}{{}}
  }

  int main() {
    return 0;
  }`.removeUnittests.should.equal(`module test;

  @("It should find this test")


  int main() {
    return 0;
  }`);
}

@("It should remove unittest versions")
unittest{
  `module test;

  version(    unittest  )
  {
    import trial.discovery;
    {}{{}}
  }

  int main() {
    return 0;
  }`.removeUnittests.should.equal(`module test;


  int main() {
    return 0;
  }`);
}

@("It should remove unittest versions")
unittest{
  `module test;

version (unittest)
{
  import fluent.asserts;
}`.removeUnittests.should.equal(`module test;
`);
}