-module(rebar3_lfe_prv_compile).

-export([init/1,
         do/1,
         format_error/1]).
-export([compile/1,
         compile_app/1, compile_app/2,
         compile_dir/4,
         compile_file/3]).

-include("rebar3_lfe.hrl").

-define(PROVIDER, compile).
-define(NAMESPACE_PROVIDER, {?NAMESPACE, ?PROVIDER}).
-define(DEPS, [{default, lock}, {default, compile}]).

%% =============================================================================
%% Plugin API
%% =============================================================================

init(State) ->
  Description = "Compile LFE project",
  Provider = providers:create([
      {namespace,  ?NAMESPACE},
      {name,       ?PROVIDER},
      {module,     ?MODULE},
      {bare,       true},
      {deps,       ?DEPS},
      {example,    "rebar3 lfe compile"},
      {opts,       []},
      {short_desc, Description},
      {desc,       info(Description)}
  ]),
  {ok, rebar_state:add_provider(State, Provider)}.

do(State) ->
    rebar_paths:set_paths([deps, plugins], State),
    %%rebar3_lfe_utils:run_prehooks(State, ?PROVIDER),
    compile(State).

format_error({missing_artifact, File}) ->
    io_lib:format("Missing artifact ~s", [File]);
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

%% =============================================================================
%% Public functions
%% =============================================================================

compile(State) ->
    rebar_api:debug("Compiling LFE apps ...", []),
    rebar_paths:set_paths([deps], State),
    Apps = rebar3_lfe_utils:get_apps(State),
    [compile_app(AppInfo, State) || AppInfo <- Apps],
    {ok, State}.

compile_app(AppInfo) ->
    compile_app(AppInfo, []).

compile_app(AppInfo, State) ->
    rebar_api:debug("Compiling ~ts", [rebar_app_info:name(AppInfo)]),
    %%rebar3_lfe_utils:copy_app_src(AppInfo, State),
    rebar_otp_app:compile(State, AppInfo),
    Opts = rebar_app_info:opts(AppInfo),
    AppDir = rebar_app_info:dir(AppInfo),
    OtherSrcDirs1 = rebar_dir:src_dirs(Opts),
    OtherSrcDirs = rebar3_lfe_utils:get_src_dirs(AppDir, OtherSrcDirs1),
    SourceDirs1 = rebar3_lfe_utils:get_src_dirs(AppDir, ["src"]),
    SourceDirs = SourceDirs1 ++ OtherSrcDirs,
    OutDir = rebar3_lfe_utils:relative_out_dir(AppInfo),
    FirstFiles = rebar3_lfe_utils:get_first_files(Opts, AppDir),
    Config = rebar3_lfe_utils:config(OutDir, Opts),
    rebar_api:debug("OtherSrcDirs: ~p", [OtherSrcDirs]),
    rebar_api:debug("AppInfoDir: ~p", [AppDir]),
    rebar_api:debug("SourceDirs: ~p", [SourceDirs]),
    rebar_api:debug("OutDir: ~p", [OutDir]),
    rebar_api:debug("FirstFiles: ~p", [FirstFiles]),

    %%rebar_api:debug("AppInfo: ~p", [AppInfo]),
    %%rebar_api:debug("State: ~p", [State]),
    rebar_api:debug("Config: ~p", [dict:fetch(lfe_opts, Config)]),

    rebar3_lfe_package:generate_sources(SourceDirs),
    [compile_dir(Config, FirstFiles, Dir, OutDir) || Dir <- SourceDirs],
    rebar3_lfe_package:clean_sources(SourceDirs),
    rebar_api:debug("Finished compile.", []),
    code:add_patha(rebar3_lfe_utils:out_dir(rebar_app_info:dir(AppInfo))).

compile_dir(Config, FirstFiles, SourceDir, TargetDir) ->
    rebar3_lfe_utils:ensure_dir(TargetDir),
    rebar_base_compiler:run(Config, FirstFiles,
                            SourceDir, ".lfe", TargetDir, ".beam",
                            fun compile_file/3).

compile_file(Source, Target, Config) ->
    rebar_api:debug("Compiling ~s ...",
                      [rebar3_lfe_utils:relative(Source)]),
    rebar_api:debug("Output file: ~s",[Target]),
    LfeOpts = dict:fetch(lfe_opts, Config),
    rebar_api:debug("Config: ~p", [LfeOpts]),
    CompileResults = lfe_comp:file(Source, LfeOpts),
    rebar_api:debug("Compile results: ~p", [CompileResults]),
    case CompileResults of
        {ok, _Mod} ->
            ok;
        {ok, _Mod, Ws} ->
            rebar_base_compiler:ok_tuple(Source, Ws);
        {error, [], Es, Ws} ->
            rebar_base_compiler:error_tuple(Source, Es, Ws, Config);
        {error, [{error, Es, Ws}|_], _Es, _Ws} ->
            rebar_base_compiler:error_tuple(Source, Es, Ws, Config)
    end.

%% =============================================================================
%% Internal functions
%% =============================================================================

-spec info(string()) -> iolist().
info(Description) ->
    io_lib:format(
        "~n~s~n"
        "~n"
        "No additional configuration options are required to compile~n"
        "LFE (*.lfe) files. The rebar 'erl_opts' setting is reused by~n"
        "LFE. For more information, see the rebar documentation for~n"
        "'erl_opts'.~n",
        [Description]).
