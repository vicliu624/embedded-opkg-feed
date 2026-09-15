// Deterministically archive a Go vendor directory using the reviewed Go host
// toolchain.  GNU tar and gzip output differs across host versions even when
// every file is identical, so this small standard-library-only program is part
// of the locked Go-vendor build interface.
package main

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var epoch = time.Unix(0, 0).UTC()

func fail(err error) {
	fmt.Fprintln(os.Stderr, "deterministic Go vendor archive:", err)
	os.Exit(1)
}

func canonicalMode(info fs.FileInfo) int64 {
	if info.Mode().Perm()&0111 != 0 {
		return 0755
	}
	return 0644
}

func archiveVendor(root, output string) (err error) {
	rootInfo, err := os.Lstat(root)
	if err != nil {
		return err
	}
	if !rootInfo.IsDir() || rootInfo.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("vendor root must be a real directory: %s", root)
	}

	file, err := os.OpenFile(output, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := file.Close(); err == nil && closeErr != nil {
			err = closeErr
		}
	}()

	gzipWriter, err := gzip.NewWriterLevel(file, gzip.BestCompression)
	if err != nil {
		return err
	}
	gzipWriter.Header.ModTime = epoch
	gzipWriter.Header.OS = 255
	tarWriter := tar.NewWriter(gzipWriter)
	defer func() {
		if closeErr := tarWriter.Close(); err == nil && closeErr != nil {
			err = closeErr
		}
		if closeErr := gzipWriter.Close(); err == nil && closeErr != nil {
			err = closeErr
		}
	}()

	parent := filepath.Dir(root)
	return filepath.WalkDir(root, func(path string, _ fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relative, err := filepath.Rel(parent, path)
		if err != nil {
			return err
		}
		name := filepath.ToSlash(relative)
		if name == "." || strings.HasPrefix(name, "../") || strings.Contains(name, "/../") {
			return fmt.Errorf("unsafe vendor path: %s", path)
		}
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		header := &tar.Header{
			Name:       name,
			ModTime:    epoch,
			AccessTime: time.Time{},
			ChangeTime: time.Time{},
			Uid:        0,
			Gid:        0,
			Format:     tar.FormatPAX,
		}
		switch {
		case info.IsDir():
			header.Name += "/"
			header.Typeflag = tar.TypeDir
			header.Mode = 0755
		case info.Mode().IsRegular():
			header.Typeflag = tar.TypeReg
			header.Mode = canonicalMode(info)
			header.Size = info.Size()
		case info.Mode()&os.ModeSymlink != 0:
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			header.Typeflag = tar.TypeSymlink
			header.Mode = 0777
			header.Linkname = link
		default:
			return fmt.Errorf("unsupported vendor file type: %s", path)
		}
		if err := tarWriter.WriteHeader(header); err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return nil
		}
		input, err := os.Open(path)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(tarWriter, input)
		closeErr := input.Close()
		if copyErr != nil {
			return copyErr
		}
		return closeErr
	})
}

func main() {
	if len(os.Args) != 3 {
		fail(fmt.Errorf("usage: %s VENDOR_DIRECTORY OUTPUT_TAR_GZ", os.Args[0]))
	}
	if err := archiveVendor(os.Args[1], os.Args[2]); err != nil {
		fail(err)
	}
}
