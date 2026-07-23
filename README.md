# Project Title: 
###  "Zero-Trust Multi-Tenant Kubernetes: Namespace-Scoped RBAC, Aggregated ClusterRoles, and Least-Privilege Service Accounts"

## Tool versions: 
 - Kubernetes 1.36 (RBAC API rbac.authorization.k8s.io/v1 — stable since 1.8, unchanged surface but the built-in default roles have shifted underneath it), 
 - kubectl 1.36.x, 
 - Pod Security Admission (stable, restricted/baseline/privileged standards), 
 - ValidatingAdmissionPolicy (GA since 1.30, CEL-based)

# What You Will Build
•	Two isolated tenant namespaces (team-alpha, team-beta) with namespace-scoped Role/RoleBinding pairs that give each team exactly what it needs and nothing else
•	A platform-level ClusterRole built the aggregated way — the pattern Kubernetes' own admin/edit/view roles use — instead of one giant hand-written rule list
•	Dedicated ServiceAccounts per application (never the namespace default SA), with automount disabled where it isn't needed
•	A live demonstration of a current, real gotcha in the built-in edit/admin roles that catches teams off guard in production
•	A full audit workflow using kubectl auth can-i and impersonation to prove what an identity can actually do — not what you think it can do

# The RBAC Mental Model (in plain language)

Think of it like a building's keycard system, because that's really what it is:

### RBAC object	& Keycard analogy

```mermaid
flowchart LR
    subgraph RBACobject["RBAC Objects (myapp_1)"]
        RBACobject1["Subject (User, Group, or ServiceAccount)"]
        RBACobject2["Role"]
        RBACobject3["ClusterRole"]
        RBACobject4["RoleBinding"]
        RBACobject5["ClusterRoleBinding"]
    end

    subgraph Keycard["Keycard Analogy"]
        KeycardAttr1["The person (Who is holding a card)"]
        KeycardAttr2["The list of doors (that a type of card can open — but only in one building (namespace))" " Note: A Role with no RoleBinding does nothing. It's a card design sitting in a drawer — nobody's holding it."]
        KeycardAttr3["A card-template (that works the same way in every building on the campus, or opens doors that don't belong to any single building (like the parking garage — a cluster-scoped resource))"]
        KeycardAttr4["The act (that is actually handing a specific person a specific card, valid for one building)"]
        KeycardAttr5["A specific person ( that is handing a card that is valid campus-wide)"]
    end

    RBACobject1 --> KeycardAttr1
    RBACobject2 --> KeycardAttr2
    RBACobject3 --> KeycardAttr3
    RBACobject4 --> KeycardAttr4
    RBACobject5 --> KeycardAttr5
```

---

## Four things to memorize because they're the four ways people get RBAC wrong:
1.	A Role with no RoleBinding does nothing. It's a card design sitting in a drawer — nobody's holding it.
2.	A ClusterRole is just a template until it's bound. You can bind a ClusterRole with a RoleBinding (not just a ClusterRoleBinding) — that gives the cluster-wide permission list but scoped down to one namespace's doors only. This is the single most useful and most under-used pattern in RBAC.
3.	RBAC is purely additive. There is no "deny" rule. You cannot subtract a permission with a second binding — you can only ever grant more. If you want to restrict, you write a narrower Role, you don't try to negate a broader one.
4.	ClusterRoleBinding bypasses every namespace boundary you've built. Every one in your cluster deserves a code-review-level look, because it's the one object that ignores everything else in this tutorial.



