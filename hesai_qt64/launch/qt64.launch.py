"""Launch the Hesai driver against this repo's tracked config, plus RViz2.

Upstream's launch/start.py reads config.yaml from inside the driver's installed
share directory. That directory lives in the gitignored colcon workspace, so any
tuning done there is untracked and lost on a re-clone. The node accepts a
`config_path` parameter, so point it at config/qt64.yaml here instead and keep
the configuration under version control.

Paths resolve relative to this file, so the repo works from any clone location.
"""
import os

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)


def generate_launch_description():
    config = os.path.join(PROJECT, "config", "qt64.yaml")
    rviz_config = os.path.join(PROJECT, "rviz", "qt64.rviz")

    for path in (config, rviz_config):
        if not os.path.isfile(path):
            raise FileNotFoundError(path)

    return LaunchDescription([
        DeclareLaunchArgument(
            "rviz", default_value="true",
            description="Start RViz2 alongside the driver.",
        ),
        DeclareLaunchArgument(
            "config", default_value=config,
            description="Path to the driver YAML config.",
        ),
        Node(
            namespace="hesai_ros_driver",
            package="hesai_ros_driver",
            executable="hesai_ros_driver_node",
            output="screen",
            parameters=[{"config_path": LaunchConfiguration("config")}],
        ),
        Node(
            namespace="rviz2",
            package="rviz2",
            executable="rviz2",
            arguments=["-d", rviz_config],
            condition=IfCondition(LaunchConfiguration("rviz")),
        ),
    ])
