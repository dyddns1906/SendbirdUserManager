//
//  RequestManager.swift
//  
//
//  Created by Yongun Lim on 2023/11/28.
//

import Foundation

public class RequestManager {
    private let maxConcurrentRequests: Int
    private var activeRequests = 0
    private let queue: DispatchQueue
    private var timer: Timer?
    
    init(maxConcurrentRequests: Int,
         queue: DispatchQueue = DispatchQueue(label: "com.SendbirdUserManager.RequestManager")) {
        self.maxConcurrentRequests = maxConcurrentRequests
        self.queue = queue
    }
    
    func enqueueRequest(_ request: @escaping () -> Void, failure: @escaping () -> Void) {
        resetTimer()
        queue.sync {
            if activeRequests < maxConcurrentRequests {
                activeRequests += 1
                printIfDebug("lim:::>success\(activeRequests)")
                request()
            } else {
                printIfDebug("lim:::>failure\(activeRequests)")
                failure()
            }
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.queue.sync {
                self?.activeRequests = 0
                printIfDebug("Timer fired - activeRequests reset to 0")
            }
        }
    }
}
