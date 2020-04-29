#! /bin/sh

fail () {
    printf "\nERROR: %s\n" "$1" >&2
    exit 1
}

log () {
    if [ -t 1 ] # is stdout a terminal?
    then
        printf "\x1B[1m== %s\x1B[0m\n" "$1"
    else
        printf "== %s\n" "$1"
    fi
}

testdir="/tmp/minpkg-test"
rootfs="$testdir/rootfs"
pkg="$testdir/pkg"
tmpfile="$testdir/tmpfile"

log "Creating test directory structure"
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

log "Initializing rootfs for package management"
$minpkg init || fail "'init' command failed"

log "Testing 'to' command"
$minpkg to "$testdir/foo-1.2.3.tar" > "$tmpfile" || fail "'to' command failed"
printf "version\n" | cmp -s "$tmpfile" || fail "wrong 'to' output"

log "Installing foo-1.2.3"
$minpkg add "$testdir/foo-1.2.3.tar" || fail "'add' command failed"
printf "1.2.3" | cmp -s "$rootfs/version" || fail "bad rootfs state"

log "Installing foo-2.3.4"
$minpkg add "$testdir/foo-2.3.4.tar" || fail "'add' command failed"
printf "2.3.4" | cmp -s "$rootfs/version" || fail "bad rootfs state"

log "Testing 'match' command"
$minpkg match version > "$tmpfile"  || fail "'match' command failed"
printf "foo-2.3.4\nfoo-1.2.3\n" | cmp -s "$tmpfile" || fail "wrong 'match' output"

log "Testing 'from' command"
$minpkg from version > "$tmpfile" || fail "'from' command failed"
printf "foo-2.3.4\n" | cmp -s "$tmpfile" || fail "wrong 'from' output"

log "Raising foo-1.2.3"
$minpkg raise foo-1.2.3 || fail "'raise' command failed"
printf "1.2.3" | cmp -s "$rootfs/version" || fail "bad rootfs state"

log "Checking 'raise' command"
$minpkg match version > "$tmpfile" || fail "'match' command failed"
printf "foo-1.2.3\nfoo-2.3.4\n" | cmp -s "$tmpfile" || fail "wrong 'match' output"

log "Testing 'list' command"
$minpkg list > "$tmpfile" || fail "'list' command failed"
printf "foo-2.3.4\nfoo-1.2.3\n" | cmp -s "$tmpfile" || fail "wrong 'list' output"

log "Packing foo-1.2.3"
log "(also testing MINPKG_ROOT env var and minpkg installed by 'init')"
rm -rf "$testdir/foo-1.2.3.tar"
cd "$testdir"
MINPKG_ROOT=$rootfs $rootfs/bin/minpkg pack foo-1.2.3 || fail "'pack' command failed"
cd -
$minpkg to "$testdir/foo-1.2.3.tar" > "$tmpfile" || fail "'to' command failed"
printf "version\n" | cmp -s "$tmpfile" || fail "wrong 'to' output"

log "Uninstalling foo-1.2.3"
$minpkg del foo-1.2.3 || fail "'del' command failed"
printf "2.3.4" | cmp -s "$rootfs/version" || fail "bad rootfs state"

log "Installing packed foo-1.2.3"
$minpkg add "$testdir/foo-1.2.3.tar" || fail "'add' command failed"
printf "1.2.3" | cmp -s "$rootfs/version" || fail "bad rootfs state"

log "Deleting test directory structure"
rm -rf "$testdir"

printf "\nALL TESTS PASSED!\n"
