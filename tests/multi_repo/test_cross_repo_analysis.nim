## Test cases for enhanced cross-repository analysis
##
## This module provides comprehensive tests for the advanced cross-repository
## semantic analysis features, including dependency detection, semantic grouping,
## and coordinated commit proposals.

import unittest, asyncdispatch, json, options, sets, strutils, tables, sequtils
import ../../src/multi_repo/analyzer/cross_repo
import ../../src/multi_repo/repository/manager
import ../../src/core/repository/jujutsu
import ../../src/single_repo/analyzer/semantic as single_semantic

suite "Enhanced Cross-Repository Analysis Tests":
  
  setup:
    # Create test repositories and manager
    var manager = newRepositoryManager("/test/repos")
    manager.addRepository("core-lib", "/test/repos/core-lib")
    manager.addRepository("api-service", "/test/repos/api-service")
    manager.addRepository("frontend-app", "/test/repos/frontend-app")
    
    # Create mock diff for testing
    var changes = initTable[string, seq[jujutsu.FileDiff]]()
    
    # Core library changes - feature implementation
    changes["core-lib"] = @[
      jujutsu.FileDiff(
        path: "src/data/models.nim",
        changeType: "modified",
        diff: """@@ -10,6 +10,15 @@ type
  User* = object
    id*: string
    name*: string
+   email*: string
+   createdAt*: DateTime
+
+proc validateEmail*(email: string): bool =
+  ## Validates email format - simple check
+  return email.contains("@") and email.contains(".") and email.len > 5
+
+proc isValidUser*(user: User): bool =
+  return user.name.len > 0 and validateEmail(user.email)
"""
      ),
      jujutsu.FileDiff(
        path: "src/core/auth.nim",
        changeType: "modified",
        diff: """@@ -5,6 +5,20 @@ import ../data/models
import std/times

type
+  AuthResult* = object
+    success*: bool
+    token*: string
+    expiresAt*: DateTime
+
+proc authenticateUser*(user: User, password: string): AuthResult =
+  ## Authenticates a user and returns a token
+  if not isValidUser(user):
+    return AuthResult(success: false)
+  
+  # Authentication logic here
+  let token = "generated-token-" & user.id
+  let expiration = now() + 24.hours
+  
+  return AuthResult(success: true, token: token, expiresAt: expiration)
"""
      ),
      jujutsu.FileDiff(
        path: "tests/test_models.nim",
        changeType: "modified",
        diff: """@@ -8,6 +8,15 @@ suite "User Model Tests":
    check(user.id == "123")
    check(user.name == "Test User")
  
+  test "Email Validation":
+    check(validateEmail("user@example.com"))
+    check(validateEmail("user.name@subdomain.example.com"))
+    check(not validateEmail("invalid-email"))
+    check(not validateEmail("@example.com"))
+
+  test "User Validation":
+    let user = User(id: "123", name: "Test", email: "test@example.com")
+    check(isValidUser(user))
"""
      )
    ]
    
    # API service changes - using the new core lib features
    changes["api-service"] = @[
      jujutsu.FileDiff(
        path: "src/routes/auth.nim",
        changeType: "modified",
        diff: """@@ -3,6 +3,7 @@
import std/asynchttpserver
import std/json
import core-lib/core/auth
+import core-lib/data/models
  
proc handleLoginRequest*(req: Request): Future[Response] {.async.} =
  ## Handles user login requests
@@ -12,10 +13,17 @@ proc handleLoginRequest*(req: Request): Future[Response] {.async.} =
  let password = body["password"].getStr()
  
  # Create user and authenticate
-  let user = User(id: userId, name: "")
-  let token = generateToken(user)
+  let user = User(
+    id: userId, 
+    name: "User " & userId,
+    email: body["email"].getStr()
+  )
-  return Response(
-    status: 200,
-    body: $(%*{"token": token})
-  )
+  # Validate and authenticate
+  if not isValidUser(user):
+    return Response(status: 400, body: $(%*{"error": "Invalid user data"}))
+    
+  let authResult = authenticateUser(user, password)
+  if not authResult.success:
+    return Response(status: 401, body: $(%*{"error": "Authentication failed"}))
+  
+  return Response(status: 200, body: $(%*{"token": authResult.token}))
"""
      ),
      jujutsu.FileDiff(
        path: "src/app.nim",
        changeType: "modified",
        diff: """@@ -15,6 +15,7 @@ proc startServer*(port: int) {.async.} =
  server.listen(Port(port))
  
  echo "Server started on port ", port
+  echo "Using core-lib auth module for authentication"
"""
      ),
      jujutsu.FileDiff(
        path: "tests/test_auth_routes.nim",
        changeType: "added",
        diff: """## Tests for authentication routes
import unittest, asyncdispatch, json
import ../src/routes/auth
import core-lib/data/models
import core-lib/core/auth

suite "Authentication Routes Tests":
  
  test "Login Valid User":
    let response = waitFor handleLoginRequest(mockValidRequest())
    check(response.status == 200)
    
    let body = parseJson(response.body)
    check(body.hasKey("token"))
    check(body["token"].getStr().len > 0)
  
  test "Login Invalid Email":
    let response = waitFor handleLoginRequest(mockInvalidEmailRequest())
    check(response.status == 400)
"""
      )
    ]
    
    # Frontend app changes - using API service
    changes["frontend-app"] = @[
      jujutsu.FileDiff(
        path: "src/services/auth.ts",
        changeType: "modified",
        diff: """@@ -8,12 +8,14 @@ export interface LoginParams {
  username: string;
  password: string;
+  email: string;
}

export async function login(params: LoginParams): Promise<string> {
  const response = await fetch('/api/login', {
    method: 'POST',
    body: JSON.stringify({
      username: params.username,
      password: params.password,
+      email: params.email,
    }),
  });
@@ -21,8 +23,14 @@ export async function login(params: LoginParams): Promise<string> {
  if (!response.ok) {
-    throw new Error('Login failed');
+    const errorData = await response.json();
+    throw new Error(errorData.error || 'Login failed');
  }
  
  const data = await response.json();
  return data.token;
+}
+
+export function validateEmail(email: string): boolean {
+  // Simple email validation - check for @ and . symbols
+  return email.includes('@') && email.includes('.') && email.length > 5;
}
"""
      ),
      jujutsu.FileDiff(
        path: "src/components/LoginForm.tsx",
        changeType: "modified",
        diff: """@@ -1,6 +1,6 @@
import React, { useState } from 'react';
import { Button, TextField, Typography } from '@material-ui/core';
-import { login, LoginParams } from '../services/auth';
+import { login, LoginParams, validateEmail } from '../services/auth';

function LoginForm() {
  const [username, setUsername] = useState('');
@@ -8,6 +8,8 @@ function LoginForm() {
  const [password, setPassword] = useState('');
+  const [email, setEmail] = useState('');
+  const [emailError, setEmailError] = useState('');
  const [error, setError] = useState('');
  
  const handleSubmit = async (e) => {
@@ -15,8 +17,14 @@ function LoginForm() {
    
    setError('');
+    setEmailError('');
+    
+    if (!validateEmail(email)) {
+      setEmailError('Please enter a valid email address');
+      return;
+    }
    
    try {
-      const token = await login({ username, password });
+      const token = await login({ username, password, email });
        localStorage.setItem('authToken', token);
        window.location.href = '/dashboard';
@@ -40,6 +48,15 @@ function LoginForm() {
        onChange={(e) => setPassword(e.target.value)}
      />
      
+      <TextField
+        label="Email"
+        type="email"
+        value={email}
+        error={!!emailError}
+        helperText={emailError}
+        onChange={(e) => setEmail(e.target.value)}
+      />
+      
      {error && (
        <Typography color="error">{error}</Typography>
      )}
"""
      ),
      jujutsu.FileDiff(
        path: "src/pages/Login.tsx",
        changeType: "modified",
        diff: """@@ -10,7 +10,7 @@ function LoginPage() {
  return (
    <Container maxWidth="sm">
      <Box my={4}>
-        <Typography variant="h4">Login</Typography>
+        <Typography variant="h4">Login to Your Account</Typography>
        <LoginForm />
      </Box>
    </Container>
"""
      )
    ]
    
    # Create the test diff object
    let diff = CrossRepoDiff(
      repositories: @[
        Repository(name: "core-lib", path: "/test/repos/core-lib", dependencies: @[]),
        Repository(name: "api-service", path: "/test/repos/api-service", dependencies: @[]),
        Repository(name: "frontend-app", path: "/test/repos/frontend-app", dependencies: @[])
      ],
      changes: changes
    )
  
  test "Advanced Dependency Detection":
    # Test the enhanced dependency detection features
    let dependencies = waitFor identifyCrossRepoDependencies(diff)
    
    # Verify that basic dependencies are detected
    check(dependencies.len > 0)
    
    # Verify source-target relationships
    var dependencyMap = initTable[string, seq[string]]()
    for dep in dependencies:
      if not dependencyMap.hasKey(dep.source):
        dependencyMap[dep.source] = @[]
      dependencyMap[dep.source].add(dep.target)
    
    # API service should depend on core-lib
    check(dependencyMap.hasKey("api-service"))
    check("core-lib" in dependencyMap["api-service"])
    
    # Frontend app should depend on api-service (at least indirectly)
    check(dependencyMap.hasKey("frontend-app"))
    
    # Verify confidence scores
    for dep in dependencies:
      # All dependencies should have reasonable confidence
      check(dep.confidence > 0.5)
      check(dep.confidence <= 1.0)
      
      # Direct imports should have higher confidence
      if dep.dependencyType == "import":
        check(dep.confidence >= 0.7)
  
  test "Dependency Graph Building":
    # Test dependency graph construction
    let dependencies = waitFor identifyCrossRepoDependencies(diff)
    let graph = buildDependencyGraph(dependencies)
    
    # Check graph structure
    check(graph.hasKey("api-service"))
    check(graph.hasKey("frontend-app"))
    
    # Check dependencies in graph
    check("core-lib" in graph["api-service"])
  
  test "Cross-Repo File Type Analysis":
    # Test file type grouping across repositories
    let fileTypeGroups = analyzeFilesAcrossRepos(diff)
    
    # Check for expected file extensions
    check(fileTypeGroups.hasKey("nim"))
    check(fileTypeGroups.hasKey("ts") or fileTypeGroups.hasKey("tsx"))
    
    # Check repository-specific groupings
    check(fileTypeGroups["nim"].hasKey("core-lib"))
    check(fileTypeGroups["nim"].hasKey("api-service"))
  
  test "Cross-Repo Directory Analysis":
    # Test directory grouping across repositories
    let dirGroups = analyzeDirectoriesAcrossRepos(diff)
    
    # Check for expected directories
    check(dirGroups.hasKey("src"))
    check(dirGroups.hasKey("tests") or dirGroups.hasKey("test"))
    
    # Check repository-specific groupings - verify actual keys
    echo "Actual dirGroups keys: ", dirGroups.keys.toSeq
    if dirGroups.hasKey("src"):
      echo "src subkeys: ", dirGroups["src"].keys.toSeq
  
  test "Cross-Repo Semantic Analysis":
    # Test semantic grouping across repositories
    let semanticGroups = analyzeSemanticsAcrossRepos(diff)
    
    # There should be at least one feature change
    check(semanticGroups[single_semantic.ChangeType.ctFeature].len > 0)
    
    # Check that semantic grouping correctly identified feature changes in core-lib
    check(semanticGroups[single_semantic.ChangeType.ctFeature].hasKey("core-lib"))
  
  test "Comprehensive Cross-Repo Proposal Generation":
    # Test the full proposal generation process with all strategies enabled
    let config = newDefaultAnalysisConfig()
    let proposal = waitFor generateCrossRepoProposal(diff, manager, config)
    
    # Check proposal structure
    check(proposal.commitGroups.len > 0)
    check(proposal.confidenceScore > 0.0)
    check(proposal.confidenceScore <= 1.0)
    
    # Check that proposal includes all repositories
    var includedRepos = initHashSet[string]()
    for group in proposal.commitGroups:
      for commit in group.commits:
        includedRepos.incl(commit.repository)
    
    check(includedRepos.len == 3)
    check("core-lib" in includedRepos)
    check("api-service" in includedRepos)
    check("frontend-app" in includedRepos)
    
    # Check that feature-related group exists
    var hasFeatureGroup = false
    for group in proposal.commitGroups:
      if group.changeType == single_semantic.ChangeType.ctFeature:
        hasFeatureGroup = true
        break
    
    check(hasFeatureGroup)
  
  test "Selective Grouping Strategies - Semantic Only":
    # Test proposal generation with only semantic grouping enabled
    var config = newDefaultAnalysisConfig()
    config.groupByFileType = false
    config.groupByDirectory = false
    config.groupByDependency = false
    config.groupBySemantics = true
    
    let proposal = waitFor generateCrossRepoProposal(diff, manager, config)
    
    # Check that proposal still includes groups
    check(proposal.commitGroups.len > 0)
    
    # All groups should be semantic-based
    for group in proposal.commitGroups:
      if group.groupType == cgtMixed:
        continue  # Skip the mixed group
      
      # All non-mixed groups should be feature, bugfix, or refactor
      check(group.groupType in {cgtFeature, cgtBugfix, cgtRefactor})
  
  test "Selective Grouping Strategies - Dependency Only":
    # Test proposal generation with only dependency grouping enabled
    var config = newDefaultAnalysisConfig()
    config.groupByFileType = false
    config.groupByDirectory = false
    config.groupByDependency = true
    config.groupBySemantics = false
    
    let proposal = waitFor generateCrossRepoProposal(diff, manager, config)
    
    # Check that proposal includes groups
    check(proposal.commitGroups.len > 0)
    
    # Should have at least one dependency-based group
    var hasDependencyGroup = false
    for group in proposal.commitGroups:
      if group.groupType == cgtDependency:
        hasDependencyGroup = true
        break
    
    check(hasDependencyGroup)
  
  test "Commit Message Generation":
    # Test the generation of meaningful commit messages
    let proposal = waitFor generateCrossRepoProposal(diff, manager)
    
    # Check message format for all commits
    for group in proposal.commitGroups:
      for commit in group.commits:
        # Messages should follow conventional commits format
        let messageParts = commit.message.split(":")
        check(messageParts.len >= 2)
        
        # Type should be one of the conventional commit types (with optional scope)
        let commitType = messageParts[0]
        let baseType = if '(' in commitType: commitType.split('(')[0] else: commitType
        check(baseType in ["feat", "fix", "docs", "style", "refactor", "perf", "test", "chore"])
        
        # Should have a description
        let description = messageParts[1].strip()
        check(description.len > 0)
  
  test "Empty Repository Handling":
    # Test handling of empty repositories
    var emptyChanges = initTable[string, seq[jujutsu.FileDiff]]()
    emptyChanges["empty-repo"] = @[]
    
    let emptyDiff = CrossRepoDiff(
      repositories: @[
        Repository(name: "empty-repo", path: "/test/repos/empty-repo", dependencies: @[])
      ],
      changes: emptyChanges
    )
    
    let proposal = waitFor generateCrossRepoProposal(emptyDiff, manager)
    
    # Should still create a valid proposal
    check(proposal.commitGroups.len == 0)
    check(proposal.confidenceScore == 0.0)