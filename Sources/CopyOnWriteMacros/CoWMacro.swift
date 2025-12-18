// CoWMacro.swift
// Implementation of the @CoW macro

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// Information about a stored property extracted from the struct
struct StoredProperty {
    let name: String
    let type: TypeSyntax
    let defaultValue: ExprSyntax?
    let accessLevel: String?
    let isVar: Bool
}

// MARK: - CoWMacro

public struct CoWMacro {}

// MARK: - MemberMacro

extension CoWMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Ensure we're attached to a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw CoWMacroError.onlyApplicableToStruct
        }

        // Extract stored properties
        let properties = extractStoredProperties(from: structDecl)

        guard !properties.isEmpty else {
            throw CoWMacroError.noStoredProperties
        }

        // Filter to only var properties for CoW storage
        // let properties stay as regular stored properties on the struct
        let varProperties = properties.filter { $0.isVar }

        guard !varProperties.isEmpty else {
            throw CoWMacroError.noVarProperties
        }

        // Generate the Storage class (only var properties)
        let storageClass = generateStorageClass(properties: varProperties)

        // Generate the storage property
        let storageProperty: DeclSyntax = "private var storage: Storage"

        // Generate ensureUnique method
        let ensureUnique: DeclSyntax = """
            private mutating func ensureUnique() {
                if !isKnownUniquelyReferenced(&storage) {
                    storage = Storage(copying: storage)
                }
            }
            """

        // Generate initializer (only var properties)
        let initializer = generateInitializer(properties: varProperties)

        return [
            storageClass,
            storageProperty,
            ensureUnique,
            initializer,
        ]
    }
}

// MARK: - MemberAttributeMacro

extension CoWMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only apply to variable declarations
        guard let varDecl = member.as(VariableDeclSyntax.self) else {
            return []
        }

        // Skip computed properties
        guard !isComputedProperty(varDecl) else {
            return []
        }

        // Skip static properties
        guard !varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
            return []
        }

        // Skip the storage property we generate
        for binding in varDecl.bindings {
            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                if identifier == "storage" {
                    return []
                }
            }
        }

        // Skip let properties - accessor macros can't be attached to let in Swift 6
        // These are handled directly in MemberMacro
        guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
            return []
        }

        // Add @_CoWProperty to transform this into a computed property
        return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("_CoWProperty")))]
    }
}

// MARK: - CoWPropertyMacro (Accessor Macro)

public struct CoWPropertyMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return []
        }

        let isLet = varDecl.bindingSpecifier.tokenKind == .keyword(.let)

        if isLet {
            // Read-only accessor for let properties
            return [
                """
                get {
                    storage.\(raw: identifier)
                }
                """
            ]
        } else {
            // Read-write accessors for var properties
            return [
                """
                get {
                    storage.\(raw: identifier)
                }
                """,
                """
                set {
                    ensureUnique()
                    storage.\(raw: identifier) = newValue
                }
                """
            ]
        }
    }
}

// MARK: - Helper Functions

private func extractStoredProperties(from structDecl: StructDeclSyntax) -> [StoredProperty] {
    var properties: [StoredProperty] = []

    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        // Skip computed properties
        guard !isComputedProperty(varDecl) else {
            continue
        }

        // Skip static properties
        guard !varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
            continue
        }

        // Extract access level
        let accessLevel = extractAccessLevel(from: varDecl.modifiers)

        // Check if it's var or let
        let isVar = varDecl.bindingSpecifier.tokenKind == .keyword(.var)

        for binding in varDecl.bindings {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                continue
            }

            // Get the type annotation or infer from initializer
            let type: TypeSyntax
            if let typeAnnotation = binding.typeAnnotation?.type {
                type = typeAnnotation
            } else if let initializer = binding.initializer?.value {
                // Try to infer type from literal
                type = inferType(from: initializer) ?? TypeSyntax(IdentifierTypeSyntax(name: .identifier("Any")))
            } else {
                continue // Can't determine type
            }

            let defaultValue = binding.initializer?.value

            properties.append(StoredProperty(
                name: identifier,
                type: type,
                defaultValue: defaultValue,
                accessLevel: accessLevel,
                isVar: isVar
            ))
        }
    }

    return properties
}

private func isComputedProperty(_ varDecl: VariableDeclSyntax) -> Bool {
    for binding in varDecl.bindings {
        if let accessor = binding.accessorBlock {
            switch accessor.accessors {
            case .getter:
                return true
            case .accessors(let accessorList):
                for accessor in accessorList {
                    if accessor.accessorSpecifier.tokenKind == .keyword(.get) ||
                       accessor.accessorSpecifier.tokenKind == .keyword(.set) {
                        return true
                    }
                }
            }
        }
    }
    return false
}

private func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> String? {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public): return "public"
        case .keyword(.private): return "private"
        case .keyword(.fileprivate): return "fileprivate"
        case .keyword(.internal): return "internal"
        case .keyword(.package): return "package"
        default: continue
        }
    }
    return nil
}

private func inferType(from expr: ExprSyntax) -> TypeSyntax? {
    if expr.is(IntegerLiteralExprSyntax.self) {
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Int")))
    } else if expr.is(FloatLiteralExprSyntax.self) {
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Double")))
    } else if expr.is(StringLiteralExprSyntax.self) {
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("String")))
    } else if expr.is(BooleanLiteralExprSyntax.self) {
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Bool")))
    }
    return nil
}

// MARK: - Code Generation

private func generateStorageClass(properties: [StoredProperty]) -> DeclSyntax {
    // Generate storage properties
    let storageProperties = properties.map { prop -> String in
        "var \(prop.name): \(prop.type)"
    }.joined(separator: "\n        ")

    // Generate primary initializer parameters
    let initParams = properties.map { prop -> String in
        if let defaultValue = prop.defaultValue {
            return "\(prop.name): \(prop.type) = \(defaultValue)"
        } else {
            return "\(prop.name): \(prop.type)"
        }
    }.joined(separator: ", ")

    // Generate primary initializer assignments
    let initAssignments = properties.map { prop -> String in
        "self.\(prop.name) = \(prop.name)"
    }.joined(separator: "\n            ")

    // Generate copying initializer assignments
    let copyAssignments = properties.map { prop -> String in
        "self.\(prop.name) = other.\(prop.name)"
    }.joined(separator: "\n            ")

    return """
        private final class Storage: @unchecked Sendable {
            \(raw: storageProperties)

            init(\(raw: initParams)) {
                \(raw: initAssignments)
            }

            init(copying other: Storage) {
                \(raw: copyAssignments)
            }
        }
        """
}

private func generateInitializer(properties: [StoredProperty]) -> DeclSyntax {
    // Find the most permissive access level among properties
    let accessLevels = properties.compactMap { $0.accessLevel }
    let accessModifier: String
    if accessLevels.contains("public") {
        accessModifier = "public "
    } else if accessLevels.contains("package") {
        accessModifier = "package "
    } else {
        accessModifier = ""
    }

    // Generate initializer parameters
    let initParams = properties.map { prop -> String in
        if let defaultValue = prop.defaultValue {
            return "\(prop.name): \(prop.type) = \(defaultValue)"
        } else {
            return "\(prop.name): \(prop.type)"
        }
    }.joined(separator: ", ")

    // Generate storage initialization arguments
    let storageArgs = properties.map { prop -> String in
        "\(prop.name): \(prop.name)"
    }.joined(separator: ", ")

    return """
        \(raw: accessModifier)init(\(raw: initParams)) {
            self.storage = Storage(\(raw: storageArgs))
        }
        """
}

// MARK: - Errors

enum CoWMacroError: Error, CustomStringConvertible {
    case onlyApplicableToStruct
    case noStoredProperties
    case noVarProperties

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@CoW can only be applied to structs"
        case .noStoredProperties:
            return "@CoW requires at least one stored property"
        case .noVarProperties:
            return "@CoW requires at least one var property (let properties are not included in CoW storage)"
        }
    }
}
