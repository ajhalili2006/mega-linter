# !/usr/bin/env python3
"""
Automatically sync recommended extensions from .vscode/extensions.json to .gitpod.yml
"""

# pylint: disable=import-error
import json5 as json # This is needed so comments on .vscode/extensions.json are rendered fine.
import logging
import os
import re
import subprocess
import sys
from datetime import date, datetime
from shutil import copyfile
from typing import Any
import yaml

REPO_HOME = os.path.dirname(os.path.abspath(__file__)) + os.path.sep + ".."
BASE_MAGE = "gitpod/workspace-full"

def replace_in_file(file_path, start, end, content, add_new_line=True):
    # Read in the file
    with open(file_path, "r", encoding="utf-8") as file:
        file_content = file.read()
    # Replace the target string
    if add_new_line is True:
        replacement = f"{start}\n{content}\n{end}"
    else:
        replacement = f"{start}{content}{end}"
    regex = rf"{start}([\s\S]*?){end}"
    file_content = re.sub(regex, replacement, file_content, re.DOTALL)
    # Write the file out again
    with open(file_path, "w", encoding="utf-8") as file:
        file.write(file_content)
    logging.info("Updated " + file.name)

def updateWSExtensions():
  extConfigPath = f"{REPO_HOME}/.vscode/extensions.json"
  gitpodConfigPath = f"{REPO_HOME}/.gitpod.yml"

  # Load the files first as streams and the load it as Python dictionaries
  with open(extConfigPath) as f:
      extConfigVSC = json.load(f)
  with open(gitpodConfigPath) as f:
        gpConfig = yaml.load(f)

  # Pull and dump to memory first
  recommends = extConfigVSC["recommendations"]
  gpConfig['vscode']['extensions'] = recommends

  # When done, dump the changes to our Gitpod config
  with open(gitpodConfigPath, 'w') as configDump:
      yaml.dump(obj, configDump)

if __name__ == "__main__":
    try:
        logging.basicConfig(
            force=True,
            level=logging.INFO,
            format="%(asctime)s [%(levelname)s] %(message)s",
            handlers=[logging.StreamHandler(sys.stdout)],
        )
    except ValueError:
        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s [%(levelname)s] %(message)s",
            handlers=[logging.StreamHandler(sys.stdout)],
        )
    
    # Generate vscode.extensions array in .gitpod.yml
    updateWSExtensions()
