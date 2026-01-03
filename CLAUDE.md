# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Retrieval-Augmented Generation (RAG) system for course materials. It combines ChromaDB vector storage, Anthropic's Claude API with tool calling, and a FastAPI backend to enable semantic search and AI-powered Q&A over educational content.

## Development Commands

### Setup

```bash
# Install dependencies
uv sync

# Set up environment variables
# Create .env file with: ANTHROPIC_API_KEY=your_key_here
```

### Running the Application

```bash
# Quick start (from project root)
./run.sh

# Manual start (from project root)
cd backend && uv run uvicorn app:app --reload --port 8000
```

The application serves both the API and frontend:

- Web Interface: `http://localhost:8000`
- API Documentation: `http://localhost:8000/docs`

### Python Environment

- This project uses `uv` as the package manager (not pip/poetry)
- Python 3.13+ required
- Virtual environment is in `.venv/`
- Run Python commands with: `uv run python <script>`
- Run any command in the venv with: `uv run <command>`

## Architecture

### Core System Flow

The RAG system follows this request flow:

1. **User Query** → FastAPI endpoint (`app.py`)
2. **RAGSystem** orchestrates components (`rag_system.py`)
3. **AIGenerator** calls Claude API with tool definitions (`ai_generator.py`)
4. **Claude decides** whether to use the search tool based on the query
5. **If tool use**: **ToolManager** executes **CourseSearchTool** (`search_tools.py`)
6. **VectorStore** performs semantic search in ChromaDB (`vector_store.py`)
7. **SearchResults** returned to Claude with context
8. **Claude synthesizes** final answer from search results
9. **Response** returned with answer + sources

### Key Components

#### RAGSystem (`rag_system.py`)

Main orchestrator that connects all components. Handles:

- Adding course documents and folders
- Processing user queries with conversation context
- Coordinating between document processor, vector store, AI generator, and tool manager

#### VectorStore (`vector_store.py`)

Manages two ChromaDB collections:

- **course_catalog**: Course metadata (titles, instructors, lessons) for course name resolution
- **course_content**: Actual course material chunks for semantic search

Key method: `search(query, course_name, lesson_number)` - handles fuzzy course name matching and filtered content search.

#### AIGenerator (`ai_generator.py`)

Interfaces with Anthropic Claude API:

- Uses tool calling (not legacy prompt-based RAG)
- Handles multi-turn tool execution flow
- System prompt emphasizes minimal tool use and direct answers
- Model: `claude-sonnet-4-20250514`

#### Tool System (`search_tools.py`)

- **Tool** abstract base class for extensibility
- **CourseSearchTool** implements search with course name + lesson filters
- **ToolManager** registers tools and executes them by name
- Tools return sources for UI display

#### DocumentProcessor (`document_processor.py`)

Processes course documents with expected format:

```
Course Title: [title]
Course Link: [url]
Course Instructor: [name]

Lesson 0: [lesson title]
Lesson Link: [url]
[content...]

Lesson 1: [lesson title]
...
```

Chunks text with sentence-based splitting (800 char chunks, 100 char overlap).

#### SessionManager (`session_manager.py`)

Manages conversation history:

- Creates session IDs for tracking conversations
- Maintains last N message exchanges (configurable via `MAX_HISTORY`)
- Provides formatted history for Claude context

### Data Models (`models.py`)

- **Course**: Represents a course with title (unique ID), link, instructor, lessons
- **Lesson**: Lesson number, title, link
- **CourseChunk**: Content chunk with course_title, lesson_number, chunk_index for vector storage

### Configuration (`config.py`)

All settings centralized as a dataclass:

- `ANTHROPIC_API_KEY`: From .env file
- `ANTHROPIC_MODEL`: Claude model to use
- `EMBEDDING_MODEL`: Sentence transformer model (all-MiniLM-L6-v2)
- `CHUNK_SIZE`: 800 characters
- `CHUNK_OVERLAP`: 100 characters
- `MAX_RESULTS`: 5 search results
- `MAX_HISTORY`: 2 conversation exchanges
- `CHROMA_PATH`: ./chroma_db (relative to backend/)

### Frontend

Simple HTML/CSS/JS interface in `frontend/`:

- `index.html`: Main page
- `script.js`: API calls and UI updates
- `style.css`: Styling

Served as static files by FastAPI.

## Important Implementation Details

### Vector Search Strategy

The system uses a two-step search:

1. **Course resolution**: Fuzzy match user's course name against course_catalog using vector similarity
2. **Content search**: Search course_content with exact course_title filter + optional lesson_number filter

This allows natural language course queries like "MCP" to match "Introduction to Model Context Protocol".

### Tool Calling Pattern

Unlike traditional RAG that always retrieves context, this system uses Claude's tool calling:

- Claude decides whether to search based on the query
- General knowledge questions answered directly without search
- Course-specific questions trigger tool use
- System prompt enforces "one search per query maximum" to control costs

### Document Loading

On startup, FastAPI loads all documents from `../docs/` directory:

- Processes .txt, .pdf, .docx files
- Skips already-indexed courses (checks course titles)
- Idempotent: safe to restart without clearing DB

To force a fresh rebuild: `rag_system.add_course_folder(path, clear_existing=True)`

### Session Management

Sessions are in-memory only (not persisted). Session IDs are auto-created if not provided in API requests. Frontend maintains session_id across requests for conversation continuity.

## Common Modification Patterns

### Adding a new tool

1. Create class extending `Tool` in `search_tools.py`
2. Implement `get_tool_definition()` and `execute()`
3. Register in `RAGSystem.__init__()`: `self.tool_manager.register_tool(NewTool())`

### Changing chunking strategy

Modify `DocumentProcessor.chunk_text()` in `document_processor.py`. Current strategy is sentence-based with character limits.

### Adding new document formats

Extend `DocumentProcessor.read_file()` to handle additional file types (currently handles .txt, .pdf, .docx).

### Modifying search filters

Update `VectorStore._build_filter()` and `CourseSearchTool` input schema to support new filter parameters.

## API Endpoints

### POST `/api/query`

Request:

```json
{
  "query": "string",
  "session_id": "string" (optional)
}
```

Response:

```json
{
  "answer": "string",
  "sources": ["string"],
  "session_id": "string"
}
```

### GET `/api/courses`

Response:

```json
{
  "total_courses": 0,
  "course_titles": ["string"]
}
```
