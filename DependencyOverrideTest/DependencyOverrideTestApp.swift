//
//  DependencyOverrideTestApp.swift
//  DependencyOverrideTest
//
//  Created by Dominik Grodl on 02.11.2023.
//

import SwiftUI
import Dependencies
import SwiftUINavigation

struct NamesClient: Sendable {
    var getAllNames: @Sendable () -> [String]
}

extension NamesClient: DependencyKey {
    static var liveValue: NamesClient {
        NamesClient(
            getAllNames: { ["All", "names"] }
        )
    }
    
    static var mockValue: NamesClient {
        NamesClient(
            getAllNames: { ["Mock"] }
        )
    }
}

extension DependencyValues{
    var namesClient: NamesClient {
        get { self[NamesClient.self] }
        set { self[NamesClient.self] = newValue }
    }
}

struct GetAllNamesClient: Sendable {
    var getAllNames: @Sendable () -> [String]
}

extension GetAllNamesClient: DependencyKey {
    static var liveValue: GetAllNamesClient {
        // Neither putting the dependency here, not in the closure helps
        //@Dependency(\.namesClient) var client
        .init(
            getAllNames: {
                @Dependency(\.namesClient) var client
                return client.getAllNames()
            }
        )
    }
    
    static var mockValue: GetAllNamesClient {
        .init(
            getAllNames: { ["mock"] }
        )
    }
}

extension DependencyValues {
    var getAllNamesClient: GetAllNamesClient {
        get { self[GetAllNamesClient.self] }
        set { self[GetAllNamesClient.self] = newValue }
    }
}

@Observable
final class ViewModel {
    @ObservationIgnored
    @Dependency(\.getAllNamesClient) private var getAllNamesClient
    
    var names: [String] = []
    var destination: Destination? = nil
    
    func getAllNames() {
        names = getAllNamesClient.getAllNames()
    }
    
    // This works
    func goToChildWithGetAllNamesClientOverrideOnly() {
        let viewModel = withDependencies(from: self) {
            $0.getAllNamesClient = .mockValue
        } operation: {
            ChildViewModel()
        }
        
        destination = .child(viewModel)
    }
    
    // This does not work
    func goToChildWithNamesClientOverride() {
        let viewModel = withDependencies(from: self) {
            $0.namesClient = .mockValue
        } operation: {
            ChildViewModel()
        }
        
        destination = .child(viewModel)
    }
    
    enum Destination {
        case child(ChildViewModel)
    }
}

@Observable
final class ChildViewModel {
    @ObservationIgnored
    @Dependency(\.getAllNamesClient) private var getAllNamesClient
    
    var names: [String] = []
    
    func getAllNames() {
        names = getAllNamesClient.getAllNames()
    }
}

@main
struct DependencyOverrideTestApp: App {
    @State private var viewModel = ViewModel()
    
    var body: some Scene {
        WindowGroup {
            AppView(viewModel: viewModel)
        }
    }
}

struct AppView: View {
    @Bindable var viewModel: ViewModel
    
    var body: some View {
        NavigationStack {
            List(
                viewModel.names,
                id: \.self,
                rowContent: Text.init
            )
            .onAppear {
                viewModel.getAllNames()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("NamesClient override") {
                        viewModel.goToChildWithNamesClientOverride()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("GetAllNamesClient override") {
                        viewModel.goToChildWithGetAllNamesClientOverrideOnly()
                    }
                }
            }
            .sheet(
                unwrapping: $viewModel.destination,
                case: /ViewModel.Destination.child
            ) { model in
                ChildView(viewModel: model.wrappedValue)
            }
        }
    }
}

struct ChildView: View {
    let viewModel: ChildViewModel
    
    var body: some View {
        List(
            viewModel.names,
            id: \.self,
            rowContent: Text.init
        )
        .onAppear {
            viewModel.getAllNames()
        }
    }
}
