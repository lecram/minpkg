#! /bin/sh

fail () {
    printf "\nERROR: %s\n" "$1" >&2
    exit 1
}

testdir="/tmp/minpkg-test"
rootfs="$testdir/rootfs"
pkg="$testdir/pkg"
tmpfile="$testdir/tmpfile"

printf "Creating test directory structure...\n"
rm -rf "$testdir"
mkdir "$testdir" || fail "unable to create test directory at $testdir"
mkdir -p "$rootfs" "$pkg/files"
printf "version\n" > "$pkg/paths.txt"
printf "1.2.3\n2.3.4\n" | while read version
do
    printf "$version" > "$pkg/files/version"
    tar -c -C "$pkg/files" -f "$pkg/files.tar" -T "$pkg/paths.txt"
cat <<EOF > "$pkg/info.txt"
name:foo
version:$version
arch:$(uname -m)
size:$(du "$pkg/files.tar" | cut -f1)
EOF
    gzip "$pkg/files.tar"
    tar -c -C "$pkg" -f "$testdir/foo-$version.tar" info.txt paths.txt files.tar.gz
    rm "$pkg/files.tar.gz"
done

minpkg="./minpkg -r $rootfs"

printf "Initializing rootfs for package management...\n"
$minpkg init || fail "'init' command failed"

printf "Testing 'to' command...\n"
$minpkg to "$testdir/foo-1.2.3.tar" > "$tmpfile" || fail "'to' command failed"
printf "version\n" | cmp -s "$tmpfile" || fail "wrong 'to' output"

printf "Installing foo-1.2.3...\n"
$minpkg add "$testdir/foo-1.2.3.tar" || fail "'add' command failed"
printf "1.2.3" | cmp -s "$rootfs/version" || fail "bad rootfs state"

printf "Installing foo-2.3.4...\n"
$minpkg add "$testdir/foo-2.3.4.tar" || fail "'add' command failed"
printf "2.3.4" | cmp -s "$rootfs/version" || fail "bad rootfs state"

printf "Testing 'match' command...\n"
$minpkg match version > "$tmpfile"  || fail "'match' command failed"
printf "foo-2.3.4\nfoo-1.2.3\n" | cmp -s "$tmpfile" || fail "wrong 'match' output"

printf "Testing 'from' command...\n"
$minpkg from version > "$tmpfile" || fail "'from' command failed"
printf "foo-2.3.4\n" | cmp -s "$tmpfile" || fail "wrong 'from' output"

printf "Raising foo-1.2.3...\n"
$minpkg raise foo-1.2.3 || fail "'raise' command failed"
printf "1.2.3" | cmp -s "$rootfs/version" || fail "bad rootfs state"

printf "Checking 'raise' command...\n"
$minpkg match version > "$tmpfile" || fail "'match' command failed"
printf "foo-1.2.3\nfoo-2.3.4\n" | cmp -s "$tmpfile" || fail "wrong 'match' output"

printf "Testing 'list' command...\n"
$minpkg list > "$tmpfile" || fail "'list' command failed"
printf "foo-2.3.4\nfoo-1.2.3\n" | cmp -s "$tmpfile" || fail "wrong 'list' output"

printf "Packing foo-1.2.3...\n"
printf "(also testing MINPKG_ROOT env var and minpkg installed by 'init')...\n"
rm -rf "$testdir/foo-1.2.3.tar"
cd "$testdir"
MINPKG_ROOT=$rootfs $rootfs/bin/minpkg pack foo-1.2.3 || fail "'pack' command failed"
cd -
$minpkg to "$testdir/foo-1.2.3.tar" > "$tmpfile" || fail "'to' command failed"
printf "version\n" | cmp -s "$tmpfile" || fail "wrong 'to' output"

printf "Uninstalling foo-1.2.3...\n"
$minpkg del foo-1.2.3 || fail "'del' command failed"
printf "2.3.4" | cmp -s "$rootfs/version" || fail "bad rootfs state"

printf "Installing packed foo-1.2.3...\n"
$minpkg add "$testdir/foo-1.2.3.tar" || fail "'add' command failed"
printf "1.2.3" | cmp -s "$rootfs/version" || fail "bad rootfs state"

printf "Deleting test directory structure...\n"
rm -rf "$testdir"

printf "\nALL TESTS PASSED!\n"
