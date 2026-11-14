#!/usr/bin/env python3
"""BagSmith test runner (Lua 5.1 via lupa). Run from the repository root (the folder holding BagSmith/,
BagSmith_Gamepad/, BagSmith_ExamplePlugin/ and tests/).

    pip install lupa            # once
    python3 tools/run_tests.py            # everything: the core suite, then each plugin/companion set
    python3 tools/run_tests.py --quick    # the QUICK list: many core regression sets plus the plugin/companion sets
    python3 tools/run_tests.py tests/plugins_browse_tests.lua   # one set

Exit status is non-zero if anything failed. The core suite (tests/run.lua) began as the pinned 0.15.0 suite; its
by-design updates since are listed in docs/plugins/TEST-RESULTS.md and the handoff. These are mock results: the harness models
the client (tests/mock.lua) and is not evidence of behavior in the actual game.
"""
import sys, os, time
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    print("lupa (Lua 5.1) is required: pip install lupa"); sys.exit(2)

PRELUDE = '''package.path = "./tests/?.lua;" .. package.path
fails, passes = 0, 0
function check(cond, msg) if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end end
'''
QUICK = ["tests/core_scroll_1_0_1_tests.lua", "tests/core_classic_dialogs_1_0_2_tests.lua", "tests/core_item_level_1_0_2_tests.lua", "tests/core_audit_1_1_0_beta2_tests.lua", "tests/core_pawn_geometry_1_1_0_tests.lua", "tests/core_prompts_1_2_0_tests.lua", "tests/core_disenchant_1_2_0_tests.lua", "tests/core_disenchant_ui_1_2_0_tests.lua", "tests/core_mail_trade_follow_1_2_0_tests.lua", "tests/core_audit_1_2_0_beta9_tests.lua", "tests/core_audit_1_2_0_beta10_tests.lua", "tests/core_audit_1_2_0_beta11_tests.lua", "tests/core_audit_1_2_0_beta12_tests.lua", "tests/core_first_open_guard_1_2_0_tests.lua", "tests/core_audit_1_2_0_tests.lua", "tests/core_loot_helper_1_3_0_tests.lua", "tests/core_audit_1_3_0_beta1_tests.lua", "tests/core_junk_sale_1_3_1_tests.lua", "tests/core_sort_pins_1_4_0_tests.lua", "tests/core_own_drop_1_4_0_tests.lua", "tests/core_pins_custom_1_4_0_tests.lua", "tests/core_sort_off_slots_1_4_0_tests.lua", "tests/core_pins_into_all_1_4_0_tests.lua", "tests/core_audit_1_4_0_beta5_tests.lua", "tests/core_audit_1_4_0_beta6_tests.lua", "tests/core_cleanup_redraw_1_4_1_tests.lua", "tests/core_freed_slots_1_4_1_tests.lua", "tests/core_toolbar_1_4_1_tests.lua", "tests/core_bag_split_1_4_1_tests.lua", "tests/core_1_4_2_tests.lua", "tests/core_countdown_fit_1_4_2_tests.lua", "tests/core_size_note_1_4_2_tests.lua", "tests/core_corners_1_5_0_tests.lua", "tests/core_item_icons_page_1_5_0_tests.lua", "tests/core_corners_beta3_1_5_0_tests.lua", "tests/core_corners_beta4_1_5_0_tests.lua", "tests/core_audit_1_5_0_beta4_tests.lua", "tests/core_classic_tabs_1_5_0_tests.lua", "tests/core_corner_dropdowns_1_5_0_tests.lua", "tests/core_split_consumables_1_5_0_tests.lua", "tests/core_audit_1_5_0_beta10_tests.lua", "tests/core_audit_1_5_0_beta11_tests.lua", "tests/core_audit_1_5_0_beta12_tests.lua", "tests/core_audit_1_5_0_beta13_tests.lua", "tests/core_audit_1_5_0_beta14_tests.lua", "tests/core_audit_1_5_0_release_tests.lua", "tests/core_audit_1_5_0_rebuild_tests.lua", "tests/core_audit_1_5_0_third_build_tests.lua", "tests/core_loot_helper_1_5_1_tests.lua", "tests/core_audit_1_5_1_beta1_tests.lua", "tests/core_1_5_1_beta2_tests.lua", "tests/core_audit_1_5_1_beta2_tests.lua", "tests/core_1_5_2_tests.lua", "tests/core_1_5_3_tests.lua", "tests/core_1_5_4_tests.lua", "tests/core_1_5_5_tests.lua", "tests/core_1_5_6_tests.lua", "tests/core_1_5_7_tests.lua", "tests/core_1_5_8_tests.lua", "tests/core_1_6_0_tests.lua", "tests/core_1_6_0_beta4_tests.lua", "tests/core_1_6_0_beta5_tests.lua", "tests/core_1_6_0_beta6_tests.lua", "tests/core_audit_1_6_0_beta5_price_tests.lua", "tests/core_audit_1_6_0_beta5_persistence_tests.lua", "tests/core_audit_1_6_0_beta5_combat_tests.lua", "tests/core_audit_1_6_0_beta5_rearm_tests.lua", "tests/core_1_6_0_beta7_tests.lua", "tests/core_audit_1_6_0_beta6_profile_tests.lua", "tests/core_audit_1_6_0_beta6_narrow_tests.lua", "tests/core_audit_1_6_0_beta6_skin_tests.lua", "tests/core_audit_1_6_0_beta6_skin_throw_tests.lua", "tests/core_audit_1_6_0_beta6_lifecycle_tests.lua", "tests/core_audit_1_6_0_beta6_quest_read_tests.lua", "tests/core_1_6_0_beta8_tests.lua", "tests/core_audit_1_6_0_beta7_selection_tests.lua", "tests/core_audit_1_6_0_beta7_skin_lifecycle_tests.lua", "tests/core_audit_1_6_0_beta7_de_fault_tests.lua", "tests/core_audit_1_6_0_beta7_columns_tests.lua", "tests/core_audit_1_6_0_beta7_empty_options_tests.lua", "tests/core_1_6_0_beta9_tests.lua", "tests/core_audit_1_6_0_beta8_economics_tests.lua", "tests/core_audit_1_6_0_beta8_equality_tests.lua", "tests/core_audit_1_6_0_beta8_selection_tests.lua", "tests/core_audit_1_6_0_beta8_settings_combat_tests.lua", "tests/core_audit_1_6_0_beta8_skill_event_tests.lua", "tests/core_audit_1_6_0_beta8_layout_migration_tests.lua", "tests/core_1_6_0_beta10_tests.lua", "tests/core_audit_1_6_0_beta9_quest_shadow_tests.lua", "tests/core_audit_1_6_0_beta9_shadow_preview_tests.lua", "tests/core_audit_1_6_0_beta9_offstep_tests.lua", "tests/core_1_6_0_beta11_tests.lua", "tests/core_audit_1_6_0_beta10_rounding_tests.lua", "tests/core_audit_1_6_0_beta10_margins_tests.lua", "tests/core_audit_1_6_0_beta10_ui_lifecycle_tests.lua", "tests/core_1_6_0_release_tests.lua", "tests/core_audit_1_6_0_beta11_bop_confirm_tests.lua", "tests/core_audit_1_6_0_beta11_bound_lifecycle_tests.lua", "tests/core_audit_1_6_0_beta11_bound_combat_tests.lua", "tests/core_audit_1_6_0_beta11_bound_surface_tests.lua", "tests/core_audit_1_6_0_beta11_title_lifecycle_tests.lua", "tests/core_1_6_1_tests.lua", "tests/core_1_6_2_beta1_tests.lua", "tests/core_1_6_2_beta4_tests.lua", "tests/core_1_6_3_beta1_tests.lua", "tests/core_1_7_0_beta1_tests.lua", "tests/core_1_7_0_beta2_tests.lua", "tests/core_1_7_0_beta3_tests.lua", "tests/core_1_7_0_beta4_tests.lua", "tests/core_1_7_0_beta5_tests.lua", "tests/core_audit_1_7_0_beta4_loot_safety_tests.lua", "tests/core_audit_1_7_0_beta4_search_headers_tests.lua", "tests/core_1_7_0_beta6_tests.lua", "tests/core_1_7_0_beta7_tests.lua", "tests/core_1_7_0_beta8_tests.lua", "tests/core_audit_1_7_0_beta7_title_collision_tests.lua", "tests/core_audit_1_7_0_beta7_quest_safety_tests.lua", "tests/core_audit_1_7_0_beta7_whats_new_wording_tests.lua", "tests/core_1_7_0_beta9_tests.lua", "tests/core_audit_1_7_0_beta8_destroy_block_tests.lua", "tests/core_audit_1_7_0_beta8_quest_transition_tests.lua", "tests/core_audit_1_7_0_beta9_delete_matrix_tests.lua", "tests/core_audit_1_7_0_beta9_quest_hardening_tests.lua", "tests/core_1_7_0_beta10_tests.lua", "tests/core_1_7_0_beta11_tests.lua", "tests/core_1_7_0_beta12_tests.lua", "tests/core_1_7_0_beta13_tests.lua", "tests/core_audit_1_7_0_beta12_header_coin_transition_tests.lua", "tests/core_audit_1_7_0_beta12_tidy_faults_tests.lua", "tests/core_audit_1_7_0_beta12_late_mail_frame_tests.lua", "tests/core_audit_1_7_0_beta12_tidy_matrix_tests.lua", "tests/core_audit_1_7_0_beta12_representative_scroll_matrix_tests.lua", "tests/core_audit_1_7_0_beta12_target_safety_tests.lua", "tests/core_audit_1_7_0_beta12_fitting_matrix_tests.lua", "tests/core_audit_1_7_0_beta12_confirmation_lifecycle_tests.lua", "tests/core_1_7_0_beta14_tests.lua", "tests/core_audit_1_7_0_beta13_tidy_error_ownership_tests.lua", "tests/core_audit_1_7_0_beta13_tidy_guard_boundaries_tests.lua", "tests/core_audit_1_7_0_beta13_pooling_lifecycle_tests.lua", "tests/core_audit_1_7_0_beta14_currency_lifecycle_tests.lua", "tests/core_audit_1_7_0_beta14_tidy_phase_faults_tests.lua", "tests/core_1_7_1_beta1_tests.lua", "tests/core_1_7_1_beta2_tests.lua", "tests/core_1_7_1_beta4_tests.lua", "tests/core_audit_1_7_1_beta1_refusal_routes_tests.lua", "tests/core_audit_1_7_1_beta1_state_machine_tests.lua", "tests/core_audit_1_7_1_beta1_profile_unpins_tests.lua", "tests/core_audit_1_7_1_beta1_ui_routes_tests.lua", "tests/core_audit_1_7_1_beta4_routes_tests.lua", "tests/core_audit_1_7_1_beta4_state_machine_tests.lua", "tests/core_audit_1_7_1_beta4_message_locations_tests.lua", "tests/core_1_7_2_beta1_tests.lua", "tests/core_1_7_2_beta2_tests.lua", "tests/core_1_7_2_tests.lua", "tests/core_audit_1_7_2_beta2_tooltip_tests.lua", "tests/core_audit_1_7_2_beta2_shards_tests.lua", "tests/plugins_gamepad_audit_0_1_1_tests.lua", "tests/plugins_api_tests.lua", "tests/plugins_stageA_tests_obs.lua", "tests/plugins_stageObs_tests.lua",
         "tests/plugins_probeB_tests.lua", "tests/plugins_nav_tests.lua", "tests/plugins_browse_tests.lua", "tests/plugins_example_tests.lua"]

QUICK.append("tests/core_auto_anchor_tests.lua")
QUICK.extend(['tests/core_resize_movement_tests.lua', 'tests/core_resize_finish_tests.lua'])
QUICK.append("tests/core_1_7_3_beta1_tests.lua")
QUICK.append("tests/core_1_7_3_beta2_tests.lua")
QUICK.append("tests/core_1_7_3_beta4_tests.lua")
QUICK.append("tests/core_1_7_3_beta5_tests.lua")
QUICK.append("tests/core_1_7_3_beta6_tests.lua")
QUICK.extend(['tests/core_modern_border_tests.lua', 'tests/core_modern_crop_tests.lua', 'tests/core_modern_texture_tests.lua'])

def run_file(path, prelude=True, quiet=False):
    """Run one Lua set. (1.5.0-beta5, audit F6) The core suite ends with os.exit(code): that call now reports its
    code to Python through a private function and raises a private per-run token. A set passes only if it returned
    0 failures, or exited through that function with code 0 and, for prelude sets, no failed check. Any other error,
    whatever its message says, is a failure."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    token = "BAGSMITH-RUNNER-EXIT-" + os.urandom(8).hex()
    exited = {}
    def record_exit(code):
        exited["code"] = code
    lua.globals()["__bs_record_exit"] = record_exit
    lua.execute('local tok, rec = ...; os.exit = function(c) rec(c); error(tok, 0) end; __bs_record_exit = nil', token, record_exit)
    if quiet: lua.execute('print = function() end')   # the self-test's synthetic sets print nothing
    src = open(path, encoding="utf-8").read()
    code = (PRELUDE + src + '\nprint(("%d passed, %d failed"):format(passes, fails))\nreturn fails\n') if prelude else src
    t = time.time()
    try:
        fails = lua.execute(code)
    except Exception as e:  # a Lua error, or os.exit through the private exit
        msg = str(e)
        checked_fails = lua.globals()["fails"] if prelude else None
        if token in msg and "code" in exited:
            # (1.5.0-beta9) exactly 0, true or no code is success; 1 is a failure (in Python 1 == True, so
            # "code in (0, None, True)" wrongly accepted os.exit(1))
            code = exited["code"]
            ok_exit = code is None or code is True or (not isinstance(code, bool) and isinstance(code, (int, float)) and code == 0)
            fails = 0 if ok_exit else 1
            if checked_fails: fails = 1          # a failed check is a failure however the set ended
        else:
            print("ERROR:", msg[:400]); fails = 1
    print("%s: %s (%.0fs)" % (path, "ok" if not fails else "FAILED", time.time() - t))
    return int(fails or 0)

def runner_self_test():
    """(1.5.0-beta5, audit F6) The runner must fail a set that fails a check and then raises an error mentioning
    EXIT:0, and one that fails a check and then calls os.exit(0); and pass a clean os.exit(0)."""
    import tempfile
    cases = [
        ('check(false, "deliberately failing assertion")\nerror("EXIT:0 synthetic unrelated Lua error")\n', True),
        ('check(false, "deliberately failing assertion")\nos.exit(0)\n', True),
        ('error("something else went wrong")\n', True),
        ('check(true, "fine")\nos.exit(1)\n', True),
        ('check(true, "fine")\nos.exit(0)\n', False),
        ('check(true, "fine")\n', False),
    ]
    ok = True
    for src, should_fail in cases:
        with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
            f.write(src); name = f.name
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            failed = run_file(name, quiet=True) != 0
        os.unlink(name)
        if failed != should_fail: ok = False; print("runner self-test: wrong result for", repr(src[:60]))
    print("runner self-test:", "ok" if ok else "FAILED")
    return 0 if ok else 1

def main(argv):
    if not os.path.isdir("tests") or not os.path.isdir("BagSmith"):
        print("run from the repository root (needs tests/ and BagSmith/)"); return 2
    files = [a for a in argv if a.endswith(".lua")]
    bad = 0
    if files:
        for f in files: bad += run_file(f)
        return 1 if bad else 0
    print("== runner self-test")
    bad += runner_self_test()
    if "--quick" not in argv:
        print("== core suite (tests/run.lua)")
        bad += run_file("tests/run.lua", prelude=False)
    for f in QUICK:
        print("==", f); bad += run_file(f)
    print("ALL OK" if not bad else "FAILURES: %d set(s)" % bad)
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
