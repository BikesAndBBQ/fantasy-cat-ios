import Observation
import SwiftUI

typealias Pet = Components.Schemas.PetView

/// Your profile and your cats. Every function returns what to tell the person
/// if it failed, or nil. The server's sentences are written for people, so
/// they're passed through as they are.
@MainActor @Observable
final class AccountStore {
    private let model: AppModel
    private(set) var pets: [Pet] = []
    private(set) var loaded = false

    init(model: AppModel) { self.model = model }

    func loadPets() async {
        if case .ok(let ok) = try? await API.client.listPets(.init()), let body = try? ok.body.json { pets = body.pets ?? [] }
        loaded = true
    }

    // MARK: Cats

    func addCat(_ name: String) async -> String? {
        await run { try await API.client.createPet(body: .json(.init(name: name))) } ok: { if case .created = $0 { return true }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil } then: { await self.loadPets() }
    }

    func rename(_ pet: Pet, to name: String) async -> String? {
        await run { try await API.client.updatePet(path: .init(id: pet.id), body: .json(.init(name: name))) } ok: { if case .ok = $0 { return true }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil } then: { await self.loadPets() }
    }

    func setPhoto(_ pet: Pet, mediaID: Int64) async -> String? {
        await run { try await API.client.updatePet(path: .init(id: pet.id), body: .json(.init(name: pet.name, photoMediaId: mediaID))) } ok: { if case .ok = $0 { return true }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil } then: { await self.loadPets() }
    }

    /// Only a cat that has never been entered can be removed; the server says so otherwise.
    func remove(_ pet: Pet) async -> String? {
        await run { try await API.client.deletePet(path: .init(id: pet.id)) } ok: { if case .noContent = $0 { return true }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil } then: { await self.loadPets() }
    }

    // MARK: You

    func setAvatar(mediaID: Int64) async -> String? {
        await me { try await API.client.setAvatar(body: .json(.init(mediaId: mediaID))) } unpack: { if case .ok(let ok) = $0 { return try? ok.body.json }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil }
    }

    func removeAvatar() async -> String? {
        await me { try await API.client.removeAvatar(.init()) } unpack: { if case .ok(let ok) = $0 { return try? ok.body.json }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil }
    }

    func saveProfile(name: String, username: String) async -> String? {
        await me { try await API.client.updateMe(body: .json(.init(displayName: name, username: username))) } unpack: { if case .ok(let ok) = $0 { return try? ok.body.json }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil }
    }

    func setReminders(_ on: Bool, name: String) async -> String? {
        await me { try await API.client.updateMe(body: .json(.init(displayName: name, notifyEmail: on))) } unpack: { if case .ok(let ok) = $0 { return try? ok.body.json }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil }
    }

    func resendVerification() async -> String? {
        await run { try await API.client.resendVerification(.init()) } ok: { if case .noContent = $0 { return true }; return nil } problem: { if case .default(let s, let p) = $0 { return (s, try? p.body.applicationProblemJson) }; return nil } then: {}
    }

    // MARK: Plumbing

    /// Each generated operation has its own output type, so the three closures
    /// say how to read this one: did it succeed, and if not, what did the server say.
    private func run<Out>(_ call: () async throws -> Out, ok: (Out) -> Bool?, problem: (Out) -> (Int, Components.Schemas.ErrorModel?)?, then: () async -> Void) async -> String? {
        do {
            let out = try await call()
            if ok(out) == true { await then(); return nil }
            if let (status, p) = problem(out) { return Failure.from(status: status, p).message }
            return "Something went wrong. Try again."
        } catch { return Failure.from(error).message }
    }

    private func me<Out>(_ call: () async throws -> Out, unpack: (Out) -> Components.Schemas.MeBody?, problem: (Out) -> (Int, Components.Schemas.ErrorModel?)?) async -> String? {
        do {
            let out = try await call()
            if let body = unpack(out) { model.apply(body); return nil }
            if let (status, p) = problem(out) { return Failure.from(status: status, p).message }
            return "Something went wrong. Try again."
        } catch { return Failure.from(error).message }
    }
}
