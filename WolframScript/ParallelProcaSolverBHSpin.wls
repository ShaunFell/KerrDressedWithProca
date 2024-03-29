#!/usr/bin/env wolframscript
(* ::Package:: *)

(*Add downvalue to Print function to remove unnecessary print statements in terminal*)
Unprotect[Print];
Print[expr_] /; ! FreeQ[expr, _KernelObject] = Null;
Print[expr_] /; ! FreeQ[expr, s_String /; StringContainsQ[s, "KernelObject"]] = Null;
Print[expr_] /; ! FreeQ[expr, s_String /; StringContainsQ[s, "remote kernel"]] = Null;
Protect[Print];


(*$FKKSRoot = "/home/fell/Documents/Github/KerrDressedWithProca/";*) (*directory on ITP cluster to git repo*)
$FKKSRoot = FileNameJoin[FileNameSplit[ExpandFileName[First[$ScriptCommandLine]]][[1;;-3]]]<>"/";
LogFile = $FKKSRoot<>"Logs/LogFile.log";

ConfigurationParameters = Import[$FKKSRoot<>"WolframScript/Config.ini"];
LogRun = ToExpression[ConfigurationParameters["LogRun"]];
SaveToDisk = ToExpression[ConfigurationParameters["SaveToDisk"]];
NumberOfKernels = ConfigurationParameters["NumberofSlaveKernels"]//ToExpression;
OverwriteExisting = ConfigurationParameters["OverwriteExisting"]//ToExpression;

If[!TrueQ[(ConfigurationParameters["SolutionFilePath"]==Automatic)],
	$SolutionPath = ConfigurationParameters["SolutionFilePath"];,
	$SolutionPath = $FKKSRoot<>"Solutions/";
];

Print["----------------------------------"];
Print["FKKSRoot: "<>$FKKSRoot];
Print["Solution Path: "];Print["     "<>ToString@$SolutionPath];
Print["Log File Path: "];Print["     "<>ToString@LogFile];
Print["Log Run: "<>ToString[TrueQ[LogRun], InputForm]];
Print["Save to disk: "<>ToString[TrueQ[SaveToDisk], InputForm]];
Print["Overwrite Previous Solutions: "<>ToString[TrueQ[OverwriteExisting], InputForm]];
Print["----------------------------------"];

Import[FileNameJoin[{$FKKSRoot,"Packages", "KerrWithProca.wl"}]];
Import[FileNameJoin[{$FKKSRoot, "Packages", "HelperFunctions.wl"}]];
Import[FileNameJoin[{$FKKSRoot, "Packages", "ModeOvertoneWorker.wl"}]];

parameterlist = Import[$FKKSRoot<>"WolframScript/parameters.ini"]//ToExpression;
parameters = KeyMap[ToString[ToExpression[#]]&, parameterlist];
parameters["StartingX"] = parameters["\[Epsilon]"];


CreateFile[LogFile, OverwriteTarget->True];
If[\[Not]DirectoryQ[$SolutionPath], CreateDirectory[$SolutionPath]];


Messenger = "\n\n-----------------------\nBeginning Parallelized Proca Solver\n";
Print[Messenger];

(*Setup parallelization*)
CloseKernels[];
NumberKernels = Min[NumberOfKernels, (Last[parameters["mrange"]] - First[parameters["mrange"]]+1)*(Last@parameters["nrange"] - First@parameters["nrange"] + 1)];
Print["Launching "<>ToString[NumberKernels,InputForm]<>" Kernels."];
LaunchKernels[NumberKernels];
Print["Launched "<>ToString[NumberKernels, InputForm]<>" Kernels. Distributing definitions and import packages."];
DistributeDefinitions[parameters, WorkerFunction, $SolutionPath, $FKKSRoot, LogFile, LogRun];
ParallelEvaluate[Import[FileNameJoin[{$FKKSRoot, "Packages", "KerrWithProca.wl"}]]];




(*Execute parallelized kerr solver*)
Print["Executing parallel routine..."];
runStartTime = AbsoluteTime[];
Evaluators = Flatten@Table[
				ParallelSubmit[{\[Chi]v}, WorkerFunction[\[Chi]v, parameters, LogFile, OverwritePrevious->OverwriteExisting]],
				{\[Chi]v, parameters["\[Chi]range"] // First, parameters["\[Chi]range"] // Last, parameters["\[Chi]res"]}
			];
WaitAll[Evaluators];



(*Final Message*)
runEndTime = AbsoluteTime[];
Print["Finished! Total Time: "<>ToString[N[Round[runEndTime-runStartTime]/60], InputForm]<>" Minutes"];	
			
(*Cleanup*)
CloseKernels[];	
