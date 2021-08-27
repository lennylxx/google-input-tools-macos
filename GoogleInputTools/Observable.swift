//
//  Observable.swift
//  GoogleInputTools
//
//  Created by lennylxx on 8/24/21.
//

import Foundation

class Observable<T> {

    init(_ value: T) {
        self.value = value
    }

    var value: T {
        didSet {
            self.observer?(self.value)
        }
    }

    private var observer: ((T) -> Void)?

    func subscribe(_ observer: @escaping (T) -> Void) {
        self.observer = observer
    }
}
