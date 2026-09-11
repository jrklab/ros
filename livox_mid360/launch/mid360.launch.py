"""Launch the Livox driver against this repo's tracked config, plus RViz2.

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
    config = os.path.join(PROJECT, "config", "MID360_config.json")
    rviz_config = os.path.join(PROJECT, "rviz", "mid360.rviz")

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
            description="Path to the Livox driver JSON config.",
        ),
        Node(
            package="livox_ros_driver2",
            executable="livox_ros_driver2_node",
            name="livox_lidar_publisher",
            output="screen",
            parameters=[{
                "xfer_format": 0,          # 0: sensor_msgs/PointCloud2, 1: livox custom msg
                "multi_topic": 0,
                "data_src": 0,
                "publish_freq": 10.0,
                "output_data_type": 0,
                "frame_id": "livox_frame",
                "user_config_path": LaunchConfiguration("config"),
                "cmdline_input_bd_code": "livox0000000001",
            }],
        ),
        Node(
            namespace="rviz2",
            package="rviz2",
            executable="rviz2",
            arguments=["-d", rviz_config],
            condition=IfCondition(LaunchConfiguration("rviz")),
        ),
    ])
