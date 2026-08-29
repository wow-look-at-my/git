#!/bin/sh

test_description='Test the post-reset hook.'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Usage: check_post_reset <file> <old-oid> <new-oid> <mode>
#
# Verify that the post-reset hook arguments recorded in <file> match the
# expected values: <old-oid> for the previous HEAD, <new-oid> for the new
# HEAD, and <mode> for the kind of reset that was asked for.
check_post_reset () {
	test "$#" = 4 || BUG "check_post_reset takes 4 args"
	echo "old=$2 new=$3 mode=$4" >expect &&
	test_cmp expect "$1"
}

test_expect_success setup '
	test_hook --setup post-reset <<-\EOF &&
	echo "old=$1 new=$2 mode=$3" >.git/post-reset.args
	test ! -f .git/post-reset.fail
	EOF
	test_commit one &&
	test_commit two &&
	test_commit three
'

for mode in soft mixed hard merge keep
do
	test_expect_success "post-reset receives the right arguments with --$mode" '
		test_when_finished "rm -f .git/post-reset.args" &&
		git checkout -f -B reset-test three &&
		rm -f .git/post-reset.args &&
		old=$(git rev-parse HEAD) &&
		git reset --$mode HEAD^ &&
		check_post_reset .git/post-reset.args \
			"$old" "$(git rev-parse HEAD)" "$mode" &&
		test_cmp_rev HEAD two
	'
done

test_expect_success 'post-reset runs even when HEAD does not move' '
	test_when_finished "rm -f .git/post-reset.args" &&
	git checkout -f -B reset-test three &&
	rm -f .git/post-reset.args &&
	echo dirty >three.t &&
	git reset --hard &&
	check_post_reset .git/post-reset.args \
		"$(git rev-parse HEAD)" "$(git rev-parse HEAD)" hard &&
	test_cmp_rev HEAD three &&
	git diff --exit-code
'

test_expect_success 'post-reset does not run for a pathspec reset' '
	test_when_finished "rm -f .git/post-reset.args" &&
	git checkout -f -B reset-test three &&
	rm -f .git/post-reset.args &&
	echo modified >three.t &&
	git add three.t &&
	git reset -- three.t &&
	test_path_is_missing .git/post-reset.args
'

test_expect_success 'post-reset does not run for --patch' '
	test_when_finished "rm -f .git/post-reset.args" &&
	git checkout -f -B reset-test three &&
	rm -f .git/post-reset.args &&
	echo modified >three.t &&
	git add three.t &&
	test_write_lines n | git reset --patch &&
	test_path_is_missing .git/post-reset.args
'

test_expect_success 'post-reset does not run on an unborn HEAD' '
	test_when_finished "rm -rf unborn" &&
	git init unborn &&
	write_script unborn/.git/hooks/post-reset <<-\EOF &&
	echo "old=$1 new=$2 mode=$3" >post-reset.args
	EOF
	>unborn/file &&
	git -C unborn add file &&
	git -C unborn reset &&
	test_path_is_missing unborn/post-reset.args &&
	git -C unborn diff --cached --quiet
'

test_expect_success 'post-reset does not run in a bare repository' '
	test_when_finished "rm -rf bare.git bare-post-reset.args" &&
	git checkout -f -B reset-test three &&
	git clone --bare . bare.git &&
	write_script bare.git/hooks/post-reset <<-EOF &&
	echo fired >"$(pwd)/bare-post-reset.args"
	EOF
	git -C bare.git reset --soft HEAD^ &&
	test_cmp_rev "$(git -C bare.git rev-parse HEAD)" two &&
	test_path_is_missing bare-post-reset.args
'

test_expect_success 'a failing post-reset hook does not fail the reset' '
	test_when_finished "rm -f .git/post-reset.args .git/post-reset.fail" &&
	git checkout -f -B reset-test three &&
	rm -f .git/post-reset.args &&
	>.git/post-reset.fail &&
	old=$(git rev-parse HEAD) &&
	git reset --hard HEAD^ &&
	check_post_reset .git/post-reset.args \
		"$old" "$(git rev-parse HEAD)" hard &&
	test_cmp_rev HEAD two &&
	test_path_is_missing three.t
'

test_expect_success 'post-reset honors core.hooksPath' '
	test_when_finished "rm -rf custom-hooks .git/post-reset.custom" &&
	test_when_finished "rm -f .git/post-reset.args" &&
	test_when_finished "test_unconfig core.hooksPath" &&
	mkdir custom-hooks &&
	write_script custom-hooks/post-reset <<-\EOF &&
	echo "old=$1 new=$2 mode=$3" >.git/post-reset.custom
	EOF
	git config core.hooksPath "$(pwd)/custom-hooks" &&
	git checkout -f -B reset-test three &&
	rm -f .git/post-reset.args .git/post-reset.custom &&
	old=$(git rev-parse HEAD) &&
	git reset --hard HEAD^ &&
	check_post_reset .git/post-reset.custom \
		"$old" "$(git rev-parse HEAD)" hard &&
	test_path_is_missing .git/post-reset.args
'

test_expect_success 'git reset has no --no-verify option' '
	test_must_fail git reset --no-verify HEAD 2>err &&
	test_grep "unknown option" err
'

test_done
