const list = document.getElementById("task-list");
const empty = document.getElementById("empty");
const form = document.getElementById("task-form");
const input = document.getElementById("task-title");

async function api(path, options = {}) {
    const response = await fetch(`/api${path}`, {
        headers: { "Content-Type": "application/json" },
        ...options,
    });
    if (!response.ok && response.status !== 204) {
        throw new Error(`Request failed: ${response.status}`);
    }
    return response.status === 204 ? null : response.json();
}

function render(tasks) {
    list.replaceChildren();
    empty.hidden = tasks.length > 0;
    for (const task of tasks) {
        const item = document.createElement("li");
        item.classList.toggle("done", task.done);

        const checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.checked = task.done;
        checkbox.addEventListener("change", async () => {
            await api(`/tasks/${task.id}`, { method: "PATCH", body: JSON.stringify({ done: checkbox.checked }) });
            refresh();
        });

        const title = document.createElement("span");
        title.className = "title";
        title.textContent = task.title;

        const remove = document.createElement("button");
        remove.className = "delete";
        remove.setAttribute("aria-label", "Delete task");
        remove.textContent = "✕";
        remove.addEventListener("click", async () => {
            await api(`/tasks/${task.id}`, { method: "DELETE" });
            refresh();
        });

        item.append(checkbox, title, remove);
        list.append(item);
    }
}

async function refresh() {
    render(await api("/tasks"));
}

form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const title = input.value.trim();
    if (!title) return;
    await api("/tasks", { method: "POST", body: JSON.stringify({ title }) });
    input.value = "";
    refresh();
});

refresh();
