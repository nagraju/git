#!/bin/sh

test_description='Test cherry-pick continuation features

  + anotherpick: rewrites foo to d
  + picked: rewrites foo to c
  + unrelatedpick: rewrites unrelated to reallyunrelated
  + base: rewrites foo to b
  + initial: writes foo as a, unrelated as unrelated

'

. ./test-lib.sh

pristine_detach () {
	git checkout -f "$1^0" &&
	git read-tree -u --reset HEAD &&
	git clean -d -f -f -q -x
}

test_expect_success setup '
	echo unrelated >unrelated &&
	git add unrelated &&
	test_commit initial foo a &&
	test_commit base foo b &&
	test_commit unrelatedpick unrelated reallyunrelated &&
	test_commit picked foo c &&
	test_commit anotherpick foo d &&
	git config advice.detachedhead false

'

test_expect_success 'cherry-pick persists data on failure' '
	pristine_detach initial &&
	test_must_fail git cherry-pick -s base..anotherpick &&
	test_path_is_dir .git/sequencer &&
	test_path_is_file .git/sequencer/head &&
	test_path_is_file .git/sequencer/todo &&
	test_path_is_file .git/sequencer/opts &&
	git cherry-pick --reset
'

test_expect_success 'cherry-pick persists opts correctly' '
	pristine_detach initial &&
	test_must_fail git cherry-pick -s -m 1 --strategy=recursive -X patience -X ours base..anotherpick &&
	test_path_is_dir .git/sequencer &&
	test_path_is_file .git/sequencer/head &&
	test_path_is_file .git/sequencer/todo &&
	test_path_is_file .git/sequencer/opts &&
	echo "true" >expect
	git config --file=.git/sequencer/opts --get-all core.signoff >actual &&
	test_cmp expect actual &&
	echo "1" >expect
	git config --file=.git/sequencer/opts --get-all core.mainline >actual &&
	test_cmp expect actual &&
	echo "recursive" >expect
	git config --file=.git/sequencer/opts --get-all core.strategy >actual &&
	test_cmp expect actual &&
	cat >expect <<-\EOF
	patience
	ours
	EOF
	git config --file=.git/sequencer/opts --get-all core.strategy-option >actual &&
	test_cmp expect actual &&
	git cherry-pick --reset
'

test_expect_success 'cherry-pick cleans up sequencer state upon success' '
	pristine_detach initial &&
	git cherry-pick initial..picked &&
	test_path_is_missing .git/sequencer
'

test_expect_success '--reset does not complain when no cherry-pick is in progress' '
	pristine_detach initial &&
	git cherry-pick --reset
'

test_expect_success '--reset cleans up sequencer state' '
	pristine_detach initial &&
	test_must_fail git cherry-pick base..picked &&
	git cherry-pick --reset &&
	test_path_is_missing .git/sequencer
'

test_expect_success 'cherry-pick cleans up sequencer state when one commit is left' '
	pristine_detach initial &&
	test_must_fail git cherry-pick base..picked &&
	test_path_is_missing .git/sequencer &&
	echo "resolved" >foo &&
	git add foo &&
	git commit &&
	{
		git rev-list HEAD |
		git diff-tree --root --stdin |
		sed "s/$_x40/OBJID/g"
	} >actual &&
	cat >expect <<-\EOF &&
	OBJID
	:100644 100644 OBJID OBJID M	foo
	OBJID
	:100644 100644 OBJID OBJID M	unrelated
	OBJID
	:000000 100644 OBJID OBJID A	foo
	:000000 100644 OBJID OBJID A	unrelated
	EOF
	test_cmp expect actual
'

test_done
