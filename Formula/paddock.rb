# Homebrew formula for paddock. It builds from the source tarball of a
# release. The release workflow fills in the version, the checksums, the
# repository and the guest files of the VM, and attaches the result to the
# release as paddock.rb. Copy that file into a tap.
class Paddock < Formula
  desc "Run any coding-agent harness with full auto-approval inside an isolated sandbox"
  homepage "https://github.com/harnessix/paddock"
  url "https://github.com/harnessix/paddock/releases/download/v0.2.3/paddock-0.2.3.tar.gz"
  sha256 "c11b124996b411aaae9174f5f01079f74d2be1fc4b88f118d3456a42a0ad2149"
  license "MIT"

  depends_on "rust" => :build

  # The guest files of the VM backend. The release workflow takes the URLs
  # and sha256 values from packaging/vm/assets.toml.
  on_macos do
    on_arm do
      resource "vm-kernel" do
        url "https://github.com/harnessix/paddock/releases/download/v0.2.3/kernel"
        sha256 "67bac9f416af4cdc9b151e4ba4962d6515e0ad7acc53816761cf964aa6af6ea0"
      end

      resource "vm-rootfs" do
        url "https://github.com/harnessix/paddock/releases/download/v0.2.3/rootfs.img"
        sha256 "094826100f450319cac8a11dbe78fb924ca73302a6bab9ba9823ff71772b6ada"
      end
    end
  end

  def install
    # paddock update and paddock doctor read the releases of this repository.
    ENV["PADDOCK_RELEASE_REPO"] = "harnessix/paddock"
    # The source tarball of the release has no git checkout. This marks the
    # build as the release, so `paddock --version` prints only the version.
    ENV["PADDOCK_RELEASE_BUILD"] = "1"
    system "cargo", "install", *std_cargo_args
    return unless OS.mac?

    # paddock-vm owns the Linux VM of the VM backend. The Virtualization
    # framework needs the virtualization entitlement, and an ad hoc
    # signature carries it. Without it, a VM start fails.
    system "codesign", "--force", "--sign", "-",
           "--entitlements", "packaging/macos/paddock-vm.entitlements",
           bin/"paddock-vm"
    return unless Hardware::CPU.arm?

    # paddock-guest is the agent inside paddock's macOS guest. A session
    # shares it read-only, and the agent in the guest replaces itself with
    # it when the versions differ, after a check of this hash. So a paddock
    # upgrade never needs a rebuild of the golden image.
    system "codesign", "--force", "--sign", "-", bin/"paddock-guest"
    (bin/"paddock-guest.sha256").write("#{Digest::SHA256.file(bin/"paddock-guest").hexdigest}\n")

    # paddock finds the guest files here when `paddock vm setup` did not
    # install its own copy.
    (pkgshare/"vm").install "packaging/vm/assets.toml"
    # A staged file keeps the last part of its URL: kernel, rootfs.img.
    resource("vm-kernel").stage { (pkgshare/"vm").install "kernel" }
    resource("vm-rootfs").stage { (pkgshare/"vm").install "rootfs.img" }
  end

  test do
    assert_match "paddock #{version}", shell_output("#{bin}/paddock --version")
    if OS.mac?
      assert_match "com.apple.security.virtualization",
                   shell_output("codesign -d --entitlements - #{bin}/paddock-vm 2>&1")
      if Hardware::CPU.arm?
        assert_equal Digest::SHA256.file(bin/"paddock-guest").hexdigest,
                     (bin/"paddock-guest.sha256").read.strip
      end
    end
  end
end
