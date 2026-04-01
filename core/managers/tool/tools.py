from core.managers.tool.get_file import get_file
from core.managers.tool.create_file import create_file
from core.managers.tool.find_file import find_file
from core.managers.tool.list_directory import list_directory
from core.managers.tool.get_file_tree import get_file_tree
from core.managers.tool.web_search import web_search

tools = {
    "create_create_file_tool": create_file,
    "create_get_file_tool": get_file,
    "create_find_file_tool": find_file,
    "create_list_directory_tool": list_directory,
    "create_get_file_tree_tool": get_file_tree,
    "create_web_search_tool": web_search,
}
