# ros

ROS 2 projects and hardware bring-up notes. Ubuntu 24.04 + **ROS 2 Jazzy**.

Each project is self-contained in its own directory with its own colcon
workspace, so they build and break independently.

## Projects

| | |
|---|---|
| [`hesai_qt64/`](hesai_qt64/) | Live point cloud from a **Hesai Pandar QT64** LiDAR in RViz2, using Hesai's official driver. |

## Shared setup

Install ROS 2 Jazzy once, then each project's own dependencies:

```bash
sudo bash setup/install_ros2_jazzy.sh
```

Installs `ros-jazzy-desktop` (includes RViz2) and `ros-dev-tools`, sets up a
UTF-8 locale and the ROS 2 apt source, and refuses to start if less than 9 GB is
free on `/`.

## Conventions

- Scripts locate themselves (`$(dirname "${BASH_SOURCE[0]}")`), so the repo works
  from any clone path.
- Workspaces live at `<project>/ws/` and are gitignored, along with `build/`,
  `install/` and `log/`.
- Third-party drivers are cloned by each project's `build.sh` rather than
  vendored, so upstream history and submodules stay upstream. Because that clone
  is gitignored, each project keeps its own config and launch files in-repo and
  points the driver at them, rather than editing the copy inside the workspace.
- If a conda install sits ahead of `/usr/bin` in `PATH`, it will poison a colcon
  build. Project scripts strip it themselves — prefer them over a bare
  `colcon build`.
