if IsBoundGlobal("SendMsg") then
  ReadTest(Filename(DirectoriesPackageLibrary("pargap", "tst"), "pargap.tst"));
else
  Error("ParGAP is not running");
fi;

