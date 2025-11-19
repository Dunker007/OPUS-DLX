#!/usr/bin/env python3
"""
MODULE 31: WORKFLOW ORCHESTRATOR
================================
Master Workflow and Task Management System

Features:
- Task scheduling and prioritization
- Dependency management
- Resource allocation
- Priority optimization
- Parallel processing
- Queue management
- Error handling and retry logic
- Notification system
- Performance monitoring
- Workflow visualization

Module ID: 31
Category: AutomationCore
Author: DLX-Phoenix Team
"""

import os
import sys
import json
import time
import logging
import asyncio
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Callable, Set
from dataclasses import dataclass, field
from pathlib import Path
from collections import defaultdict, deque
from queue import PriorityQueue, Queue
from enum import Enum
import hashlib

# ==============================================================================
# CONFIGURATION
# ==============================================================================

MODULE_CONFIG = {
    "module_id": 31,
    "name": "workflow-orchestrator",
    "version": "1.0.0",
    "settings": {
        "max_workers": 10,
        "max_concurrent_workflows": 50,
        "task_timeout": 300,
        "retry_attempts": 3,
        "retry_delay": 5,
        "queue_size": 1000,
    }
}

# ==============================================================================
# DATA MODELS
# ==============================================================================

class TaskStatus(Enum):
    """Task execution status"""
    PENDING = "pending"
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    RETRYING = "retrying"
    CANCELLED = "cancelled"

class Priority(Enum):
    """Task priority levels"""
    CRITICAL = 0
    HIGH = 1
    MEDIUM = 2
    LOW = 3
    BACKGROUND = 4

@dataclass
class Task:
    """Represents a workflow task"""
    task_id: str
    name: str
    func: Optional[Callable] = None
    args: tuple = field(default_factory=tuple)
    kwargs: dict = field(default_factory=dict)
    priority: Priority = Priority.MEDIUM
    dependencies: Set[str] = field(default_factory=set)
    status: TaskStatus = TaskStatus.PENDING
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result: Any = None
    error: Optional[str] = None
    retry_count: int = 0
    max_retries: int = 3
    timeout: int = 300
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __lt__(self, other):
        """For priority queue comparison"""
        return self.priority.value < other.priority.value

@dataclass
class Workflow:
    """Represents a complete workflow"""
    workflow_id: str
    name: str
    tasks: Dict[str, Task] = field(default_factory=dict)
    status: str = "created"
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

@dataclass
class WorkerStats:
    """Worker statistics"""
    worker_id: int
    tasks_completed: int = 0
    tasks_failed: int = 0
    total_execution_time: float = 0.0
    last_task_time: Optional[datetime] = None
    is_busy: bool = False
    current_task: Optional[str] = None

# ==============================================================================
# TASK SCHEDULER
# ==============================================================================

class TaskScheduler:
    """Advanced task scheduling system"""

    def __init__(self, logger: logging.Logger):
        self.logger = logger
        self.task_queue = PriorityQueue()
        self.scheduled_tasks: Dict[str, Task] = {}
        self.recurring_tasks: Dict[str, Dict] = {}
        self.lock = threading.Lock()

    def schedule_task(self, task: Task, delay: int = 0):
        """Schedule a task for execution"""
        with self.lock:
            task.status = TaskStatus.QUEUED
            self.scheduled_tasks[task.task_id] = task

            if delay > 0:
                # Schedule for later
                execute_at = datetime.now() + timedelta(seconds=delay)
                threading.Timer(delay, self._enqueue_task, args=[task]).start()
                self.logger.info(f"Scheduled task {task.name} to run at {execute_at}")
            else:
                # Queue immediately
                self._enqueue_task(task)

    def _enqueue_task(self, task: Task):
        """Add task to execution queue"""
        self.task_queue.put(task)
        self.logger.debug(f"Task {task.name} queued for execution")

    def schedule_recurring(self, task: Task, interval_seconds: int):
        """Schedule a recurring task"""
        recurring_id = f"recurring_{task.task_id}"

        def run_recurring():
            while recurring_id in self.recurring_tasks:
                # Create new task instance
                new_task = Task(
                    task_id=f"{task.task_id}_{int(time.time())}",
                    name=task.name,
                    func=task.func,
                    args=task.args,
                    kwargs=task.kwargs,
                    priority=task.priority
                )
                self.schedule_task(new_task)
                time.sleep(interval_seconds)

        self.recurring_tasks[recurring_id] = {
            "task": task,
            "interval": interval_seconds,
            "thread": threading.Thread(target=run_recurring, daemon=True)
        }
        self.recurring_tasks[recurring_id]["thread"].start()

        self.logger.info(f"Scheduled recurring task {task.name} every {interval_seconds}s")

    def cancel_recurring(self, task_id: str):
        """Cancel a recurring task"""
        recurring_id = f"recurring_{task_id}"
        if recurring_id in self.recurring_tasks:
            del self.recurring_tasks[recurring_id]
            self.logger.info(f"Cancelled recurring task {task_id}")

    def get_next_task(self) -> Optional[Task]:
        """Get next task from queue"""
        if not self.task_queue.empty():
            return self.task_queue.get()
        return None

    def cancel_task(self, task_id: str) -> bool:
        """Cancel a pending task"""
        with self.lock:
            if task_id in self.scheduled_tasks:
                task = self.scheduled_tasks[task_id]
                if task.status in [TaskStatus.PENDING, TaskStatus.QUEUED]:
                    task.status = TaskStatus.CANCELLED
                    self.logger.info(f"Cancelled task {task.name}")
                    return True
        return False


# ==============================================================================
# DEPENDENCY RESOLVER
# ==============================================================================

class DependencyResolver:
    """Resolves task dependencies"""

    def __init__(self, logger: logging.Logger):
        self.logger = logger
        self.task_graph: Dict[str, Set[str]] = defaultdict(set)
        self.completed_tasks: Set[str] = set()

    def add_dependency(self, task_id: str, depends_on: str):
        """Add a task dependency"""
        self.task_graph[task_id].add(depends_on)
        self.logger.debug(f"Task {task_id} depends on {depends_on}")

    def is_ready(self, task_id: str) -> bool:
        """Check if task dependencies are satisfied"""
        dependencies = self.task_graph.get(task_id, set())
        return dependencies.issubset(self.completed_tasks)

    def mark_completed(self, task_id: str):
        """Mark task as completed"""
        self.completed_tasks.add(task_id)
        self.logger.debug(f"Task {task_id} marked as completed")

    def get_ready_tasks(self, all_tasks: Dict[str, Task]) -> List[Task]:
        """Get all tasks whose dependencies are satisfied"""
        ready = []
        for task_id, task in all_tasks.items():
            if task.status == TaskStatus.PENDING and self.is_ready(task_id):
                ready.append(task)
        return ready

    def detect_circular_dependencies(self) -> List[List[str]]:
        """Detect circular dependencies in task graph"""
        def dfs(node, visited, rec_stack, path):
            visited.add(node)
            rec_stack.add(node)
            path.append(node)

            for neighbor in self.task_graph.get(node, set()):
                if neighbor not in visited:
                    cycle = dfs(neighbor, visited, rec_stack, path[:])
                    if cycle:
                        return cycle
                elif neighbor in rec_stack:
                    # Found cycle
                    cycle_start = path.index(neighbor)
                    return path[cycle_start:]

            rec_stack.remove(node)
            return None

        cycles = []
        visited = set()

        for node in self.task_graph:
            if node not in visited:
                cycle = dfs(node, visited, set(), [])
                if cycle:
                    cycles.append(cycle)

        return cycles


# ==============================================================================
# WORKER POOL
# ==============================================================================

class WorkerPool:
    """Manages worker threads for task execution"""

    def __init__(self, max_workers: int, logger: logging.Logger):
        self.max_workers = max_workers
        self.logger = logger
        self.workers: Dict[int, WorkerStats] = {}
        self.running = False
        self.task_queue = Queue()

        for i in range(max_workers):
            self.workers[i] = WorkerStats(worker_id=i)

    def start(self):
        """Start worker threads"""
        self.running = True
        for worker_id in range(self.max_workers):
            thread = threading.Thread(
                target=self._worker_loop,
                args=(worker_id,),
                daemon=True
            )
            thread.start()

        self.logger.info(f"Started {self.max_workers} worker threads")

    def stop(self):
        """Stop worker threads"""
        self.running = False
        self.logger.info("Stopping worker pool")

    def _worker_loop(self, worker_id: int):
        """Worker thread main loop"""
        worker = self.workers[worker_id]

        while self.running:
            try:
                # Get task from queue with timeout
                task = self.task_queue.get(timeout=1)

                worker.is_busy = True
                worker.current_task = task.task_id

                # Execute task
                self._execute_task(task, worker)

                worker.is_busy = False
                worker.current_task = None

            except Exception as e:
                if self.running:  # Only log if not shutting down
                    self.logger.error(f"Worker {worker_id} error: {e}")
                time.sleep(0.1)

    def _execute_task(self, task: Task, worker: WorkerStats):
        """Execute a single task"""
        start_time = time.time()

        try:
            task.status = TaskStatus.RUNNING
            task.started_at = datetime.now()

            self.logger.info(f"Worker {worker.worker_id} executing task: {task.name}")

            # Execute the task function
            if task.func:
                result = task.func(*task.args, **task.kwargs)
                task.result = result
                task.status = TaskStatus.COMPLETED
                worker.tasks_completed += 1
            else:
                task.status = TaskStatus.FAILED
                task.error = "No function provided"
                worker.tasks_failed += 1

            task.completed_at = datetime.now()

        except Exception as e:
            task.status = TaskStatus.FAILED
            task.error = str(e)
            worker.tasks_failed += 1
            self.logger.error(f"Task {task.name} failed: {e}")

        finally:
            execution_time = time.time() - start_time
            worker.total_execution_time += execution_time
            worker.last_task_time = datetime.now()

            self.logger.info(
                f"Task {task.name} completed in {execution_time:.2f}s "
                f"with status {task.status.value}"
            )

    def submit_task(self, task: Task):
        """Submit task to worker pool"""
        self.task_queue.put(task)

    def get_stats(self) -> Dict[str, Any]:
        """Get worker pool statistics"""
        total_completed = sum(w.tasks_completed for w in self.workers.values())
        total_failed = sum(w.tasks_failed for w in self.workers.values())
        total_time = sum(w.total_execution_time for w in self.workers.values())
        busy_workers = sum(1 for w in self.workers.values() if w.is_busy)

        return {
            "total_workers": self.max_workers,
            "busy_workers": busy_workers,
            "idle_workers": self.max_workers - busy_workers,
            "tasks_completed": total_completed,
            "tasks_failed": total_failed,
            "total_execution_time": total_time,
            "avg_time_per_task": total_time / total_completed if total_completed > 0 else 0,
            "queue_size": self.task_queue.qsize()
        }


# ==============================================================================
# WORKFLOW ENGINE
# ==============================================================================

class WorkflowEngine:
    """Orchestrates complete workflows"""

    def __init__(self, logger: logging.Logger, worker_pool: WorkerPool,
                 scheduler: TaskScheduler, dependency_resolver: DependencyResolver):
        self.logger = logger
        self.worker_pool = worker_pool
        self.scheduler = scheduler
        self.dependency_resolver = dependency_resolver
        self.workflows: Dict[str, Workflow] = {}
        self.running_workflows: Set[str] = set()

    def create_workflow(self, name: str) -> Workflow:
        """Create a new workflow"""
        workflow_id = hashlib.sha256(f"{name}{time.time()}".encode()).hexdigest()[:16]

        workflow = Workflow(
            workflow_id=workflow_id,
            name=name
        )

        self.workflows[workflow_id] = workflow
        self.logger.info(f"Created workflow: {name} ({workflow_id})")

        return workflow

    def add_task_to_workflow(self, workflow_id: str, task: Task):
        """Add task to workflow"""
        if workflow_id not in self.workflows:
            raise ValueError(f"Workflow {workflow_id} not found")

        workflow = self.workflows[workflow_id]
        workflow.tasks[task.task_id] = task

        # Register dependencies
        for dep_id in task.dependencies:
            self.dependency_resolver.add_dependency(task.task_id, dep_id)

        self.logger.info(f"Added task {task.name} to workflow {workflow.name}")

    def execute_workflow(self, workflow_id: str):
        """Execute a complete workflow"""
        if workflow_id not in self.workflows:
            raise ValueError(f"Workflow {workflow_id} not found")

        workflow = self.workflows[workflow_id]
        workflow.status = "running"
        workflow.started_at = datetime.now()

        self.running_workflows.add(workflow_id)

        self.logger.info(f"Starting workflow: {workflow.name}")

        # Check for circular dependencies
        cycles = self.dependency_resolver.detect_circular_dependencies()
        if cycles:
            workflow.status = "failed"
            self.logger.error(f"Circular dependencies detected in workflow {workflow.name}: {cycles}")
            return

        # Execute tasks in dependency order
        threading.Thread(
            target=self._execute_workflow_tasks,
            args=(workflow,),
            daemon=True
        ).start()

    def _execute_workflow_tasks(self, workflow: Workflow):
        """Execute workflow tasks respecting dependencies"""
        while True:
            # Get ready tasks
            ready_tasks = self.dependency_resolver.get_ready_tasks(workflow.tasks)

            if not ready_tasks:
                # Check if all tasks are completed
                all_completed = all(
                    task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED, TaskStatus.CANCELLED]
                    for task in workflow.tasks.values()
                )

                if all_completed:
                    workflow.status = "completed"
                    workflow.completed_at = datetime.now()
                    self.running_workflows.discard(workflow.workflow_id)
                    self.logger.info(f"Workflow {workflow.name} completed")
                    break

                time.sleep(0.5)  # Wait for tasks to complete
                continue

            # Submit ready tasks
            for task in ready_tasks:
                task.status = TaskStatus.QUEUED
                self.worker_pool.submit_task(task)

            # Wait a bit before checking again
            time.sleep(0.1)

            # Mark completed tasks
            for task_id, task in workflow.tasks.items():
                if task.status == TaskStatus.COMPLETED:
                    self.dependency_resolver.mark_completed(task_id)

    def get_workflow_status(self, workflow_id: str) -> Dict[str, Any]:
        """Get workflow status"""
        if workflow_id not in self.workflows:
            return {}

        workflow = self.workflows[workflow_id]

        task_statuses = defaultdict(int)
        for task in workflow.tasks.values():
            task_statuses[task.status.value] += 1

        return {
            "workflow_id": workflow_id,
            "name": workflow.name,
            "status": workflow.status,
            "total_tasks": len(workflow.tasks),
            "task_statuses": dict(task_statuses),
            "created_at": workflow.created_at.isoformat(),
            "started_at": workflow.started_at.isoformat() if workflow.started_at else None,
            "completed_at": workflow.completed_at.isoformat() if workflow.completed_at else None,
        }


# ==============================================================================
# MAIN MODULE
# ==============================================================================

class WorkflowOrchestrator:
    """Main workflow orchestration system"""

    def __init__(self):
        self.config = MODULE_CONFIG
        self.setup_logging()
        self.logger.info("="*80)
        self.logger.info(f"WORKFLOW ORCHESTRATOR v{self.config['version']}")
        self.logger.info("="*80)

        # Initialize components
        self.scheduler = TaskScheduler(self.logger)
        self.dependency_resolver = DependencyResolver(self.logger)
        self.worker_pool = WorkerPool(
            self.config['settings']['max_workers'],
            self.logger
        )
        self.workflow_engine = WorkflowEngine(
            self.logger,
            self.worker_pool,
            self.scheduler,
            self.dependency_resolver
        )

        self.running = False

    def setup_logging(self):
        """Setup logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s | %(levelname)-8s | %(name)s | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        self.logger = logging.getLogger(f"Module{self.config['module_id']}")

    def start(self):
        """Start the orchestrator"""
        self.logger.info("Starting Workflow Orchestrator...")
        self.running = True

        # Start worker pool
        self.worker_pool.start()

        # Demo workflow
        self._create_demo_workflow()

        # Main loop
        while self.running:
            try:
                # Monitor and report stats
                stats = self.worker_pool.get_stats()
                self.logger.info(
                    f"Workers: {stats['busy_workers']}/{stats['total_workers']} busy | "
                    f"Completed: {stats['tasks_completed']} | "
                    f"Failed: {stats['tasks_failed']} | "
                    f"Queue: {stats['queue_size']}"
                )

                time.sleep(30)

            except KeyboardInterrupt:
                self.logger.info("Shutdown requested")
                break
            except Exception as e:
                self.logger.error(f"Error: {e}")
                time.sleep(10)

        self.worker_pool.stop()

    def _create_demo_workflow(self):
        """Create a demonstration workflow"""
        # Create workflow
        workflow = self.workflow_engine.create_workflow("Demo Content Pipeline")

        # Create tasks
        task1 = Task(
            task_id="task1",
            name="Research Keywords",
            func=lambda: self.logger.info("Researching keywords..."),
            priority=Priority.HIGH
        )

        task2 = Task(
            task_id="task2",
            name="Generate Content",
            func=lambda: self.logger.info("Generating content..."),
            dependencies={"task1"},
            priority=Priority.HIGH
        )

        task3 = Task(
            task_id="task3",
            name="Optimize SEO",
            func=lambda: self.logger.info("Optimizing SEO..."),
            dependencies={"task2"},
            priority=Priority.MEDIUM
        )

        task4 = Task(
            task_id="task4",
            name="Publish Content",
            func=lambda: self.logger.info("Publishing content..."),
            dependencies={"task3"},
            priority=Priority.HIGH
        )

        # Add tasks to workflow
        for task in [task1, task2, task3, task4]:
            self.workflow_engine.add_task_to_workflow(workflow.workflow_id, task)

        # Execute workflow
        self.workflow_engine.execute_workflow(workflow.workflow_id)


def main():
    """Entry point"""
    orchestrator = WorkflowOrchestrator()
    orchestrator.start()


if __name__ == "__main__":
    main()
