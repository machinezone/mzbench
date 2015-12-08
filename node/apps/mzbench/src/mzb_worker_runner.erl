-module(mzb_worker_runner).

-ifdef(deprecated_now).
-define(NOW, erlang:system_time(micro_seconds)).
-else.
-define(NOW, erlang:now()).
-endif.

-export([run_worker_script/5]).

-include_lib("mzbench_language/include/mzbl_types.hrl").

-spec run_worker_script([script_expr()], worker_env() , module(), Pool :: pid(), PoolName ::string())
    -> ok.
run_worker_script(Script, Env, {WorkerProvider, Worker}, PoolPid, PoolName) ->
    %NodeName = mzb_utility:hostname_str(node()),
    Res =
        try
            _ = random:seed(?NOW),
            ok = mzb_metrics:notify(mzb_string:format("workers.~s.started", [PoolName]), 1),
            %ok = mzb_metrics:notify(mzb_string:format("workers.~s.~s.started", [PoolName, NodeName]), 1),

            InitialState = WorkerProvider:init(Worker),
            {WorkerResult, WorkerResultState} = mzbl_interpreter:eval(Script, InitialState, Env, WorkerProvider),
            ok = mzb_metrics:notify(mzb_string:format("workers.~s.ended", [PoolName]), 1),
            %ok = mzb_metrics:notify(mzb_string:format("workers.~s.~s.ended", [PoolName, NodeName]), 1),
            _ = (catch  WorkerProvider:terminate(WorkerResult, WorkerResultState)),
            {ok, WorkerResult}
        catch
            C:E ->
                ok = mzb_metrics:notify(mzb_string:format("workers.~s.ended", [PoolName]), 1),
                %ok = mzb_metrics:notify(mzb_string:format("workers.~s.~s.ended", [PoolName, NodeName]), 1),
                ok = mzb_metrics:notify(mzb_string:format("workers.~s.failed", [PoolName]), 1),
                %ok = mzb_metrics:notify(mzb_string:format("workers.~s.~s.failed", [PoolName, NodeName]), 1),
                _ = (catch WorkerProvider:terminate({C, E, erlang:get_stacktrace()}, undefined)),
                {exception, node(), {C, E, erlang:get_stacktrace()}}
        end,

    PoolPid ! {worker_result, self(), Res},
    ok.

