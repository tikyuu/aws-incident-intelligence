"""デプロイ前に、Lambda本体と依存ライブラリをZIPへまとめる。"""

from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory


def main():
    source_dir = Path(__file__).resolve().parent
    build_dir = source_dir.parent / "build"
    build_dir.mkdir(exist_ok=True)

    with TemporaryDirectory(prefix="lambda-package-", dir=build_dir) as staging:
        subprocess.run([
            sys.executable, "-m", "pip", "install",
            "--requirement", str(source_dir / "requirements.txt"),
            "--target", staging,
            "--platform", "manylinux2014_aarch64",
            "--implementation", "cp",
            "--python-version", "3.14",
            "--only-binary=:all:",
            "--no-compile",
        ], check=True)

        shutil.copy2(source_dir / "handler.py", Path(staging) / "handler.py")
        archive = shutil.make_archive(
            str(build_dir / "incident-lambda"), "zip", root_dir=staging,
        )

    print(f"Created: {archive}")


if __name__ == "__main__":
    main()
