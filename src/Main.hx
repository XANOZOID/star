import parsing.Parser;
import lexing.Lexer;
import reporting.render.TextDiagnosticRenderer;
import reporting.Diagnostic;
import text.SourceFile;

import parsing.ast.Expr;
import parsing.ast.Cascade;
import parsing.ast.Message;

@:publicFields @:structInit class Options {
	var buildDecls = true;
	var isStdlib = false;
	var pass1 = false;
	var pass2 = false;
	var callback: Null<(typing.Project) -> Void> = null;
}

@:build(util.Overload.build())
class Main {
	static final stdout = Sys.stdout();
	public static final renderer = new TextDiagnosticRenderer(stdout);

	static var typesDump: haxe.io.Output = null;
	public static var typesDumper: typing.Dumper = null;
	static var stmtsDump: haxe.io.Output = null;
	public static var stmtsDumper: typing.Dumper = null;
	static var stdlibDump: haxe.io.Output = null;
	public static var stdlibDumper: typing.Dumper = null;
	static var compilerDump: haxe.io.Output = null;
	public static var compilerDumper: typing.Dumper = null;

	static inline function nl() {
		Sys.print("\n");
	}

	static inline function round(float: Float) {
		return Math.fround(float * 10000) / 10000;
	}

	static overload inline function testProject(path) return testProject(path, {});
	static overload function testProject(path, opt: Options) {
		Sys.println('Path: $path');
		
		var time = 0.0;

		final startProject = haxe.Timer.stamp();
		final project = typing.Project.fromMainPath(path, !opt.isStdlib);
		final stopProject = haxe.Timer.stamp();
		final timeProject = round(stopProject*1000 - startProject*1000);
		time += timeProject * 10000;
		Sys.println('Gather sources time: ${timeProject}ms');

		final files = project.allFiles();
		
		final startSources = haxe.Timer.stamp();
		for(file in files) file.initSource();
		final stopSources = haxe.Timer.stamp();
		final timeSources = round(stopSources*1000 - startSources*1000);
		time += timeSources * 10000;
		Sys.println('Init sources time: ${timeSources}ms');

		final startParse = haxe.Timer.stamp();
		for(file in files) file.parse();
		final stopParse = haxe.Timer.stamp();
		final timeParse = round(stopParse*1000 - startParse*1000);
		time += timeParse * 10000;
		Sys.println('Parse sources time: ${timeParse}ms');

		final startImports = haxe.Timer.stamp();
		for(file in files) file.buildImports();
		final stopImports = haxe.Timer.stamp();
		final timeImports = round(stopImports*1000 - startImports*1000);
		time += timeImports * 10000;
		Sys.println('Build imports time: ${timeImports}ms');

		if(opt.buildDecls) {
			final startDecls = haxe.Timer.stamp();
			for(file in files) file.buildDecls();
			final stopDecls = haxe.Timer.stamp();
			final timeDecls = round(stopDecls*1000 - startDecls*1000);
			time += timeDecls * 10000;
			Sys.println('Build declarations time: ${timeDecls}ms');
		}

		if(opt.pass1 && !files.some(f -> f.hasErrors())) {
			final startPass1 = haxe.Timer.stamp();
			project.pass1();
			final stopPass1 = haxe.Timer.stamp();
			final timePass1 = round(stopPass1*1000 - startPass1*1000);
			time += timePass1 * 10000;
			Sys.println('Typer pass 1 time: ${timePass1}ms');
		}

		if(opt.isStdlib) {
			typing.Pass2.initSTD(project);
		}

		if(opt.isStdlib) {
			typing.Project.STDLIB = project;
		}
		
		var err = null;
		if(opt.pass2 && !files.some(f -> f.hasErrors())) {
			final startPass2 = haxe.Timer.stamp();
			try typing.Pass2.resolveProject(project) catch(e: haxe.ValueException) err = e;
			final stopPass2 = haxe.Timer.stamp();
			final timePass2 = round(stopPass2*1000 - startPass2*1000);
			time += timePass2 * 10000;
			Sys.println('Typer pass 2 time: ${timePass2}ms');
		}

		err._and(e => Sys.println(e.details()));

		//if(!opt.isStdlib)
		for(file in files) {
			for(i => err in file.allErrors()) {
				#if windows
					renderer.writer.cursor(MoveDown(1));
					renderer.writer.write("\033[G");
					renderer.writer.clearLine();
					Sys.sleep(0.15);
				#end
				renderer.render(err.asDiagnostic());
				#if windows
					renderer.writer.attr(RESET);
					Sys.sleep(0.15);
					//renderer.writer.flush();
				#end

				if(i == 25) throw "too many errors!";
			}
		}
		
		Sys.println('Status: ${files.none(file -> file.hasErrors()) && err == null}');
		Sys.println('Total time: ${time / 10000}ms');

		opt.callback._and(cb => {
			cb(project);
		});

		return project;
	}

	static function main() {
		#if windows
		util.HLSys.setFlags(util.HLSys.AUTO_FLUSH | util.HLSys.WIN_UTF8);
		#end

		/*Sys.println("=== EXAMPLES ===");

		for(file in allFiles("examples")) {
			parse(newSource(file), false);
		}*/
	
		final dumpTypes = false;
		final dumpStmts = false;
			
		if(dumpTypes) { typesDump = sys.io.File.write("./dump/types.stir"); typesDumper = new typing.Dumper(typesDump); }
		if(dumpStmts) { stmtsDump = sys.io.File.write("./dump/stmts.stir"); stmtsDumper = new typing.Dumper(stmtsDump); }
		stdlibDump = sys.io.File.write("./dump/stdlib.stir"); stdlibDumper = new typing.Dumper(stdlibDump);
		compilerDump = sys.io.File.write("./dump/compiler.stir"); compilerDumper = new typing.Dumper(compilerDump);
		try {
			final stdlib = testProject("stdlib", {
				isStdlib: true,
				pass1: true,
				pass2: true
			});

			/*for(type in [
				typing.Pass2.STD_Int,
				typing.Pass2.STD_Dec,
				typing.Pass2.STD_Char,
				typing.Pass2.STD_Bool,
				typing.Pass2.STD_Str
			].concat(typing.Pass2.STD_Array.t._match(
				at(TMulti(types)) => types,
				_ => throw "bad"
			)).concat(typing.Pass2.STD_Dict.t._match(
				at(TConcrete(decl)) => [typing.Pass2.STD_Dict],
				at(TMulti(types)) => types,
				_ => throw "bad"
			))) type.t._match(
				at(TConcrete(decl) | TModular({t: TConcrete(decl)}, _)) => {
					stmtsDumper.dump(decl);
					stmtsDumper.nextLine();
					stmtsDumper.nextLine();
				},
				_ => throw "???"+type
			);*/

			final gen = new codegen.Gen(stdlibDump);

			//gen.write("Star.Core.Int:");
			//gen.newline();
			typing.Pass2.STD_Int._match(
				at({t: TConcrete(decl) | TModular({t: TConcrete(decl)}, _)}) => {
					final cls = cast(decl, typing.Class);
					gen.write(cls);
					gen.newline();
				},
				_ => throw "internal error: Star.Core.Int should be a concrete type!"
			);

			//gen.write("Star.Core.Dec:");
			//gen.newline();
			typing.Pass2.STD_Dec._match(
				at({t: TConcrete(decl) | TModular({t: TConcrete(decl)}, _)}) => {
					final cls = cast(decl, typing.Class);
					gen.write(cls);
					gen.newline();
				},
				_ => throw "internal error: Star.Core.Dec should be a concrete type!"
			);

			gen.write("Star.Core.Char:");
			gen.newline();
			typing.Pass2.STD_Char._match(
				at({t: TConcrete(decl) | TModular({t: TConcrete(decl)}, _)}) => {
					final cls = cast(decl, typing.Class);
					for(mth in cls.methods) {
						mth._match(
							at(
								//( {fuzzyName: "rootOf:" | "round:" | "log:"} is typing.MultiMethod)
								  {name: {name: "escape"}} is typing.SingleMethod) => {
								gen.write(mth);
								gen.newline();
							},
							_ => {}
						);
					}
				},
				_ => throw "internal error: Star.Core.Char should be a concrete type!"
			);

			gen.write("Star.Core.Str:");
			gen.newline();
			typing.Pass2.STD_Str._match(
				at({t: TConcrete(decl) | TModular({t: TConcrete(decl)}, _)}) => {
					final cls = cast(decl, typing.Class);
					for(mth in cls.methods) {
						mth._match(
							at(
								( {fuzzyName: "collect:" | "collectIf:" | "collectWhile:" | "addAll:"} is typing.MultiMethod)
								| {name: {name: "chars" | "hash" |
								  				"lowercase" | "uppercase" | "titlecase" | "capitalize"}} is typing.SingleMethod) => {
								gen.write(mth);
								gen.newline();
							},
							_ => {}
						);
					}
				},
				_ => throw "internal error: Star.Core.Str should be a concrete type!"
			);

			gen.write("Star.Core.Array:");
			gen.newline();
			typing.Pass2.STD_Array._match(
				at({t: TMulti([{t: TConcrete(decl) | TModular({t: TConcrete(decl)}, _)}, _, _])}) => {
					final cls = cast(decl, typing.Class);
					for(mth in cls.methods) {
						mth._match(
							at(
								( {fuzzyName: "every: by: allowPartial:" | "joinWith:" | "zip:" | "zip: collect:" | "zip: all:"} is typing.MultiMethod)
								| {name: {name: "join"}} is typing.SingleMethod) => {
								gen.write(mth);
								gen.newline();
							},
							_ => {}
						);
					}
				},
				_ => throw "internal error: Star.Core.Array should be a multi type!"
			);

			gen.write("Star.Core.Values:");
			gen.newline();
			stdlib.findType(
				List3.of([null, "Star", []], [null, "Core", []], [null, "Values", []]),
				Start,
				null
			)._match(
				at({t: TConcrete(decl) | TModular({t: TConcrete(decl)}, _)}) => {
					final proto = cast(decl, typing.Protocol);
					for(mth in proto.methods) {
						mth._match(
							at(
								( {fuzzyName: "resizeTo:"} is typing.MultiMethod)
							//	| {name: {name: "join"}} is typing.SingleMethod
							) => {
								gen.write(mth);
								gen.newline();
							},
							_ => {}
						);
					}
				},
				_ => throw "internal error: Star.Core.Values should be a concrete type!"
			);
			
			{
				final files = stdlib.allFiles();
				for(file in files) {
					stdlibDumper.dump(file);
					stdlibDumper.nextLine();
					stdlibDumper.nextLine();
					stdlibDumper.nextLine();
				}
			}

			nl();
			
			final compiler = testProject("star", {pass1: true, pass2: true}); {
				final files = compiler.allFiles();
				for(file in files) {
					compilerDumper.dump(file);
					compilerDumper.nextLine();
					compilerDumper.nextLine();
					compilerDumper.nextLine();
				}
			};
		} catch(e: haxe.Exception) {
			if(dumpTypes) typesDump.close();
			if(dumpStmts) stmtsDump.close();
			stdlibDump.close();
			compilerDump.close();
			hl.Api.rethrow(e);
		}
		if(dumpTypes) typesDump.close();
		if(dumpStmts) stmtsDump.close();
		stdlibDump.close();
		compilerDump.close();
	}
}