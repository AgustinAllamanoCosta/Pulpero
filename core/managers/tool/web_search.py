from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger


def web_search(logger: Logger) -> Tool:
    def execute(params) -> ToolResult:
        query = params.get("query")
        if query is None:
            return ToolResult(False, '', "Query is required")

        try:
            max_results = int(params.get("max_results", 5))
        except (ValueError, TypeError):
            max_results = 5

        logger.debug(f"Web search: '{query}' (max_results={max_results})")

        try:
            from duckduckgo_search import DDGS
            results = []
            with DDGS() as ddgs:
                for r in ddgs.text(query, max_results=max_results):
                    results.append({
                        "title": r.get("title", ""),
                        "url": r.get("href", ""),
                        "snippet": r.get("body", "")
                    })

            if not results:
                return ToolResult(True, "No results found for the given query.", None)

            lines = []
            for i, r in enumerate(results, 1):
                lines.append(f"[{i}] {r['title']}")
                lines.append(f"    URL: {r['url']}")
                lines.append(f"    {r['snippet']}")
                lines.append("")

            return ToolResult(True, '\n'.join(lines), None)

        except ImportError:
            return ToolResult(False, '', "duckduckgo-search package is not installed. Run: pip install duckduckgo-search")
        except Exception as e:
            return ToolResult(False, '', str(e))

    return Tool(
        "web_search",
        "Search the web for information using DuckDuckGo. Returns a list of results with title, URL, and a short snippet.",
        {
            "query": {
                "type": "string",
                "title": "query",
                "description": "The search query"
            },
            "max_results": {
                "type": "integer",
                "title": "max_results",
                "description": "Maximum number of results to return (default: 5)"
            }
        },
        ["query"],
        execute
    )
