# Homebrew formula for paddock. The release workflow of harnessix/paddock
# makes this file and attaches it to each release.
class Paddock < Formula
  desc "Run any coding-agent harness with full auto-approval inside an isolated sandbox"
  homepage "https://github.com/harnessix/paddock"
  url "https://github.com/harnessix/paddock/releases/download/v0.2.1/paddock-0.2.1.tar.gz"
  sha256 "c6406cf72af107508fe0e65158dfe36964971be2e874a322d8c688354dadd24a"
  license "MIT"

  depends_on "rust" => :build

  # The guest files of the VM backend. The release workflow takes the URLs
  # and sha256 values from packaging/vm/assets.toml.
  on_macos do
    on_arm do
      resource "vm-kernel" do
        url "https://github.com/harnessix/paddock/releases/download/v0.2.1/kernel"
        sha256 "67bac9f416af4cdc9b151e4ba4962d6515e0ad7acc53816761cf964aa6af6ea0"
      end

      resource "vm-rootfs" do
        url "https://github.com/harnessix/paddock/releases/download/v0.2.1/rootfs.img"
        sha256 "1e903e02eaa3ff6c6e13c2534b3c81c10039c10e9e4d843d2ffd5ff33cc82301"
      end
    end
  end

  def install
    # paddock update and paddock doctor read the releases of this repository.
    ENV["PADDOCK_RELEASE_REPO"] = "harnessix/paddock"
    system "cargo", "install", *std_cargo_args
    return unless OS.mac?

    # paddock-vm owns the Linux VM of the VM backend. The Virtualization
    # framework needs the virtualization entitlement, and an ad hoc
    # signature carries it. Without it, a VM start fails.
    system "codesign", "--force", "--sign", "-",
           "--entitlements", "packaging/macos/paddock-vm.entitlements",
           bin/"paddock-vm"
    return unless Hardware::CPU.arm?

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
    end
  end
end
