/// ParallelExecutor.swift
///
/// Copyright 2017-2019, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation
import Dispatch

/// A class that handles executing tasks in a round-robin fashion among
/// a fixed number of workers. It uses GCD to split the work among a fixed
/// set of queues and automatically manages balancing workloads between workers.
final class ParallelExecutor<TaskResult> {
  /// The set of worker queues on which to add tasks.
  private let queues: [DispatchQueue]

  /// The dispatch group on which to synchronize the workers.
  private let group = DispatchGroup()

  /// The results from each task executed on the workers, in non-deterministic
  /// order.
  private var results = [TaskResult]()

  /// The queue on which to protect the results array.
  private let resultQueue = DispatchQueue(label: "parallel-results")

  /// The current number of tasks, used for round-robin dispatch.
  private var taskCount = 0

  /// Creates an executor that splits tasks among the provided number of
  /// workers.
  /// - parameter numberOfWorkers: The number of workers to spawn. This number
  ///                              should be <= the number of hyperthreaded
  ///                              cores on your machine, to avoid excessive
  ///                              context switching.
  init(numberOfWorkers: Int) {
    self.queues = (0..<numberOfWorkers).map {
      DispatchQueue(label: "parallel-worker-\($0)")
    }
  }

  /// Adds the provided result to the result array, synchronized on the result
  /// queue.
  private func addResult(_ result: TaskResult) {
    resultQueue.sync {
      results.append(result)
    }
  }

  /// Synchronized on the result queue, gets a unique counter for the total
  /// next task to add to the queues.
  private var nextTask: Int {
    return resultQueue.sync {
      defer { taskCount += 1 }
      return taskCount
    }
  }

  /// Adds a task to run asynchronously on the next worker. Workers are chosen
  /// in a round-robin fashion.
  func addTask(_ work: @escaping () -> TaskResult) {
    queues[nextTask % queues.count].async(group: group) {
      self.addResult(work())
    }
  }

  /// Blocks until all workers have finished executing their tasks, then returns
  /// the set of results.
  func waitForResults() -> [TaskResult] {
    group.wait()
    return resultQueue.sync { results }
  }
}
