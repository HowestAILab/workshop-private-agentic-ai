from fastmcp import FastMCP
from datetime import datetime

from langchain_milvus import Milvus
from langchain_ollama import OllamaEmbeddings
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.prompts import PromptTemplate

URI = "../milvus.db"
loader = PyPDFLoader("./Blogpost.pdf")
documents = loader.load()
splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=128)
chunks = splitter.split_documents(documents)
embedder = OllamaEmbeddings(model="llama3.1")
vectordb = Milvus(embedding_function=embedder, connection_args={"uri": URI})
vectordb.add_documents(chunks)

rag_template = """
Je bent een assistent die vragen beantwoordt.
Gebruik de volgende stukjes context om de vraag te beantwoorden.
Vermeld altijd de bestandsnamen als bron bij je antwoorden.
Als je het antwoord niet letterlijk in de context staat, zeg dan dat je het niet weet.
Gebruik maximaal drie zinnen en houd het antwoord beknopt.

Vraag: {question}

Context:\n{context}

Antwoord: """

prompt_template = PromptTemplate.from_template(rag_template)


mcp = FastMCP("Demo 🚀")

# ================================================================================

@mcp.tool("sum")
def sum(a, b) -> str:
    """Use this tool to calculate the sum of two numbers."""
    return str(int(a) + int(b))

@mcp.tool("multiply")
def multiply(a, b) -> str:
    """Use this tool to calculate the product of two numbers."""
    return str(int(a) * int(b))

@mcp.tool("datetime")
def get_current_time() -> str:
    """Use this tool to get the current date and time."""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

@mcp.tool("search_files")
def search_files(question: str) -> str:
    """Use this tool to search for relevant information in the user's files and documents. Provide a search query or keywords to this tool."""
    print(f"🔍 Searching for relevant documents for the question: {question}")

    documents_found = vectordb.search(question, search_type="similarity", k=3)
    
    context = ""
    for document in documents_found:
        filename = document.metadata["source"]
        page = document.metadata["page_label"]
        text = document.page_content.strip()
        context += f"[{filename} - pagina {page}]\n{text}\n\n"
        
    prompt = prompt_template.invoke({"question": question, "context": context})
    print(f"🗂️ Found {len(documents_found)} relevant documents.")
    print(f"🔍 Context:\n{context}")
    return context

# ================================================================================

if __name__ == "__main__":
    mcp.run("sse", port=8000, host="localhost")