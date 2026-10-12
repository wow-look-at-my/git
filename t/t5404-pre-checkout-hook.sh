#!/bin/sh
#
# Copyright (c) 2024 Git contributors
#

test_description='Test the pre-checkout hook.'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	test_commit one &&
	test_commit two &&
	test_commit three
'

test_expect_success 'pre-checkout hook receives correct args with branch checkout' '
	test_when_finished "rm -f .git/hooks/pre-checkout .git/pre-checkout.args" &&
	test_hook pre-checkout <<-\EOF &&
	echo "$@" >.git/pre-checkout.args
	EOF
	git checkout main &&
	read old new flag <.git/pre-checkout.args &&
	test $old = $new && test $flag = 1
'

test_expect_success 'pre-checkout hook receives correct args when HEAD changes' '
	test_when_finished "rm -f .git/hooks/pre-checkout .git/pre-checkout.args" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	echo "$@" >.git/pre-checkout.args
	EOF
	git checkout two &&
	read old new flag <.git/pre-checkout.args &&
	test $old != $new && test $flag = 1
'

test_expect_success 'pre-checkout hook receives correct args with file checkout' '
	test_when_finished "rm -f .git/hooks/pre-checkout .git/pre-checkout.args" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	echo "$@" >.git/pre-checkout.args
	EOF
	git checkout main -- one.t &&
	read old new flag <.git/pre-checkout.args &&
	test $old = $new && test $flag = 0
'

test_expect_success 'pre-checkout hook can abort checkout' '
	test_when_finished "rm -f .git/hooks/pre-checkout" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	exit 1
	EOF
	test_must_fail git checkout two &&
	test "$(git symbolic-ref HEAD)" = "refs/heads/main"
'

test_expect_success 'pre-checkout hook can abort file checkout' '
	test_when_finished "rm -f .git/hooks/pre-checkout" &&
	git checkout main &&
	echo "modified" >one.t &&
	test_hook pre-checkout <<-\EOF &&
	exit 1
	EOF
	test_must_fail git checkout -- one.t &&
	test "$(cat one.t)" = "modified"
'

test_expect_success 'pre-checkout hook with git checkout -b' '
	test_when_finished "rm -f .git/hooks/pre-checkout .git/pre-checkout.args && git checkout main && git branch -D new-branch" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	echo "$@" >.git/pre-checkout.args
	EOF
	git checkout -b new-branch &&
	read old new flag <.git/pre-checkout.args &&
	test $old = $new && test $flag = 1
'

test_expect_success 'pre-checkout hook abort prevents branch creation' '
	test_when_finished "rm -f .git/hooks/pre-checkout" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	exit 1
	EOF
	test_must_fail git checkout -b should-not-exist &&
	test_must_fail git rev-parse --verify should-not-exist
'

test_expect_success 'pre-checkout is called before post-checkout' '
	test_when_finished "rm -f .git/hooks/pre-checkout .git/hooks/post-checkout .git/hook-order" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	echo "pre" >>.git/hook-order
	EOF
	test_hook post-checkout <<-\EOF &&
	echo "post" >>.git/hook-order
	EOF
	git checkout two &&
	test "$(head -n1 .git/hook-order)" = "pre" &&
	test "$(tail -n1 .git/hook-order)" = "post"
'

test_expect_success 'pre-checkout abort prevents post-checkout' '
	test_when_finished "rm -f .git/hooks/pre-checkout .git/hooks/post-checkout .git/hook-order" &&
	git checkout main &&
	test_hook pre-checkout <<-\EOF &&
	echo "pre" >>.git/hook-order
	exit 1
	EOF
	test_hook post-checkout <<-\EOF &&
	echo "post" >>.git/hook-order
	EOF
	test_must_fail git checkout two &&
	test "$(cat .git/hook-order)" = "pre" &&
	! grep -q post .git/hook-order
'

test_done
