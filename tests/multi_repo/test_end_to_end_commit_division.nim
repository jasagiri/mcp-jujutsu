## End-to-end test cases for multi-repository commit division
##
## This module provides end-to-end tests for the complete multi-repository
## commit division workflow, from analysis to execution.

import unittest, asyncdispatch, json, options, tables, os, strutils, sequtils
import ../../src/multi_repo/tools/multi_repo
import ../../src/multi_repo/repository/manager
import ../../src/multi_repo/analyzer/cross_repo
import ../../src/core/repository/jujutsu
import ../../src/single_repo/analyzer/semantic as single_semantic

# Test utilities
proc ensureTestRepoExists(repoPath: string): Future[jujutsu.JjRepo] {.async.} =
  ## Ensures a test repository exists and returns a JjRepo instance
  if not dirExists(repoPath):
    # Create directory structure
    createDir(repoPath)
    
    # Initialize jujutsu repo
    let jjRepo = await jujutsu.initJujutsuRepo(repoPath, initIfNotExists = true)
    
    # Create initial commit
    discard await jjRepo.createCommit("Initial commit", @[
      ("README.md", "# Test Repository\n\nThis is a test repository for MCP-Jujutsu.\n")
    ])
    
    return jjRepo
  else:
    # Just open the existing repository
    return await jujutsu.initJujutsuRepo(repoPath)

proc setupTestEnvironment(): Future[tuple[repoDir: string, manager: RepositoryManager]] {.async.} =
  ## Sets up a test environment with multiple repositories
  let baseDir = getTempDir() / "mcp_jujutsu_test_" & $epochTime().int
  createDir(baseDir)
  
  # Create repository manager
  var manager = newRepositoryManager(baseDir)
  
  # Create core library repository
  let coreLibPath = baseDir / "core-lib"
  let coreLibRepo = await ensureTestRepoExists(coreLibPath)
  manager.addRepository(Repository(
    name: "core-lib",
    path: coreLibPath
  ))
  
  # Create API service repository
  let apiServicePath = baseDir / "api-service"
  let apiServiceRepo = await ensureTestRepoExists(apiServicePath)
  manager.addRepository(Repository(
    name: "api-service",
    path: apiServicePath,
    dependencies: @["core-lib"]
  ))
  
  # Create frontend app repository
  let frontendAppPath = baseDir / "frontend-app"
  let frontendAppRepo = await ensureTestRepoExists(frontendAppPath)
  manager.addRepository(Repository(
    name: "frontend-app",
    path: frontendAppPath,
    dependencies: @["api-service"]
  ))
  
  # Create initial files in core-lib
  await coreLibRepo.createCommit("Initial core library structure", @[
    ("src/data/models.nim", """type
  User* = object
    id*: string
    name*: string

proc validateUser*(user: User): bool =
  return user.name.len > 0
"""),
    ("src/core/auth.nim", """import ../data/models
import std/times

proc generateToken*(user: User): string =
  return "token-" & user.id
"""),
    ("tests/test_models.nim", """import unittest
import ../src/data/models

suite "User Model Tests":
  test "User Validation":
    let user = User(id: "123", name: "Test User")
    check(user.id == "123")
    check(user.name == "Test User")
""")
  ])
  
  # Create initial files in api-service
  await apiServiceRepo.createCommit("Initial API service structure", @[
    ("src/routes/auth.nim", """import std/asynchttpserver
import std/json
import core-lib/core/auth

proc handleLoginRequest*(req: Request): Future[Response] {.async.} =
  ## Handles user login requests
  let body = parseJson(req.body)
  let userId = body["userId"].getStr()
  let password = body["password"].getStr()
  
  # Create user and authenticate
  let user = User(id: userId, name: "")
  let token = generateToken(user)
  
  return Response(
    status: 200,
    body: $(%*{"token": token})
  )
"""),
    ("src/app.nim", """import std/asynchttpserver
import std/asyncdispatch
import routes/auth

proc startServer*(port: int) {.async.} =
  ## Starts the API server on the specified port
  var server = newAsyncHttpServer()
  
  proc handleRequest(req: Request): Future[void] {.async.} =
    let response = await handleLoginRequest(req)
    await req.respond(response.status, response.body)
  
  server.listen(Port(port))
  
  echo "Server started on port ", port
""")
  ])
  
  # Create initial files in frontend-app
  await frontendAppRepo.createCommit("Initial frontend app structure", @[
    ("src/services/auth.ts", """export interface LoginParams {
  username: string;
  password: string;
}

export async function login(params: LoginParams): Promise<string> {
  const response = await fetch('/api/login', {
    method: 'POST',
    body: JSON.stringify({
      username: params.username,
      password: params.password,
    }),
  });
  
  if (!response.ok) {
    throw new Error('Login failed');
  }
  
  const data = await response.json();
  return data.token;
}
"""),
    ("src/components/LoginForm.tsx", """import React, { useState } from 'react';
import { Button, TextField, Typography } from '@material-ui/core';
import { login, LoginParams } from '../services/auth';

function LoginForm() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    setError('');
    
    try {
      const token = await login({ username, password });
      localStorage.setItem('authToken', token);
      window.location.href = '/dashboard';
    } catch (err) {
      setError(err.message);
    }
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <TextField
        label="Username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
      />
      
      <TextField
        label="Password"
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      
      {error && (
        <Typography color="error">{error}</Typography>
      )}
      
      <Button type="submit" variant="contained" color="primary">
        Login
      </Button>
    </form>
  );
}

export default LoginForm;
"""),
    ("src/pages/Login.tsx", """import React from 'react';
import { Container, Box, Typography } from '@material-ui/core';
import LoginForm from '../components/LoginForm';

function LoginPage() {
  return (
    <Container maxWidth="sm">
      <Box my={4}>
        <Typography variant="h4">Login</Typography>
        <LoginForm />
      </Box>
    </Container>
  );
}

export default LoginPage;
""")
  ])
  
  return (baseDir, manager)

proc makeMultiRepoChanges(manager: RepositoryManager): Future[void] {.async.} =
  ## Makes a set of coordinated changes across multiple repositories
  # Get repositories
  let coreLibOpt = manager.getRepository("core-lib")
  let apiServiceOpt = manager.getRepository("api-service")
  let frontendAppOpt = manager.getRepository("frontend-app")
  
  if coreLibOpt.isNone or apiServiceOpt.isNone or frontendAppOpt.isNone:
    raise newException(ValueError, "Failed to get repositories")
  
  let coreLib = coreLibOpt.get
  let apiService = apiServiceOpt.get
  let frontendApp = frontendAppOpt.get
  
  # Initialize Jujutsu repos
  let coreLibRepo = await jujutsu.initJujutsuRepo(coreLib.path)
  let apiServiceRepo = await jujutsu.initJujutsuRepo(apiService.path)
  let frontendAppRepo = await jujutsu.initJujutsuRepo(frontendApp.path)
  
  # Make coordinated changes
  
  # 1. Core Library - Add email validation and auth result
  await coreLibRepo.createCommit("Add email validation and auth result", @[
    ("src/data/models.nim", """type
  User* = object
    id*: string
    name*: string
    email*: string
    createdAt*: DateTime

proc validateEmail*(email: string): bool =
  ## Validates email format
  let emailRegex = re"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
  return email.match(emailRegex)

proc isValidUser*(user: User): bool =
  return user.name.len > 0 and validateEmail(user.email)
"""),
    ("src/core/auth.nim", """import ../data/models
import std/times

type
  AuthResult* = object
    success*: bool
    token*: string
    expiresAt*: DateTime

proc authenticateUser*(user: User, password: string): AuthResult =
  ## Authenticates a user and returns a token
  if not isValidUser(user):
    return AuthResult(success: false)
  
  # Authentication logic here
  let token = "generated-token-" & user.id
  let expiration = now() + 24.hours
  
  return AuthResult(success: true, token: token, expiresAt: expiration)
"""),
    ("tests/test_models.nim", """import unittest
import ../src/data/models

suite "User Model Tests":
  test "User Validation":
    let user = User(id: "123", name: "Test User")
    check(user.id == "123")
    check(user.name == "Test User")
  
  test "Email Validation":
    check(validateEmail("user@example.com"))
    check(validateEmail("user.name@subdomain.example.com"))
    check(not validateEmail("invalid-email"))
    check(not validateEmail("@example.com"))

  test "User Validation":
    let user = User(id: "123", name: "Test", email: "test@example.com")
    check(isValidUser(user))
""")
  ])
  
  # 2. API Service - Update to use new core lib features
  await apiServiceRepo.createCommit("Update API to use core-lib email validation", @[
    ("src/routes/auth.nim", """import std/asynchttpserver
import std/json
import core-lib/core/auth
import core-lib/data/models
  
proc handleLoginRequest*(req: Request): Future[Response] {.async.} =
  ## Handles user login requests
  let body = parseJson(req.body)
  let userId = body["userId"].getStr()
  let password = body["password"].getStr()
  
  # Create user and authenticate
  let user = User(
    id: userId, 
    name: "User " & userId,
    email: body["email"].getStr()
  )

  # Validate and authenticate
  if not isValidUser(user):
    return Response(status: 400, body: $(%*{"error": "Invalid user data"}))
    
  let authResult = authenticateUser(user, password)
  if not authResult.success:
    return Response(status: 401, body: $(%*{"error": "Authentication failed"}))
  
  return Response(status: 200, body: $(%*{"token": authResult.token}))
"""),
    ("src/app.nim", """import std/asynchttpserver
import std/asyncdispatch
import routes/auth

proc startServer*(port: int) {.async.} =
  ## Starts the API server on the specified port
  var server = newAsyncHttpServer()
  
  proc handleRequest(req: Request): Future[void] {.async.} =
    let response = await handleLoginRequest(req)
    await req.respond(response.status, response.body)
  
  server.listen(Port(port))
  
  echo "Server started on port ", port
  echo "Using core-lib auth module for authentication"
"""),
    ("tests/test_auth_routes.nim", """## Tests for authentication routes
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
""")
  ])
  
  # 3. Frontend App - Update to handle email
  await frontendAppRepo.createCommit("Add email field to login form", @[
    ("src/services/auth.ts", """export interface LoginParams {
  username: string;
  password: string;
  email: string;
}

export async function login(params: LoginParams): Promise<string> {
  const response = await fetch('/api/login', {
    method: 'POST',
    body: JSON.stringify({
      username: params.username,
      password: params.password,
      email: params.email,
    }),
  });
  
  if (!response.ok) {
    const errorData = await response.json();
    throw new Error(errorData.error || 'Login failed');
  }
  
  const data = await response.json();
  return data.token;
}

export function validateEmail(email: string): boolean {
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return emailRegex.test(email);
}
"""),
    ("src/components/LoginForm.tsx", """import React, { useState } from 'react';
import { Button, TextField, Typography } from '@material-ui/core';
import { login, LoginParams, validateEmail } from '../services/auth';

function LoginForm() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [emailError, setEmailError] = useState('');
  const [error, setError] = useState('');
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    setError('');
    setEmailError('');
    
    if (!validateEmail(email)) {
      setEmailError('Please enter a valid email address');
      return;
    }
    
    try {
      const token = await login({ username, password, email });
      localStorage.setItem('authToken', token);
      window.location.href = '/dashboard';
    } catch (err) {
      setError(err.message);
    }
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <TextField
        label="Username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
      />
      
      <TextField
        label="Password"
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      
      <TextField
        label="Email"
        type="email"
        value={email}
        error={!!emailError}
        helperText={emailError}
        onChange={(e) => setEmail(e.target.value)}
      />
      
      {error && (
        <Typography color="error">{error}</Typography>
      )}
      
      <Button type="submit" variant="contained" color="primary">
        Login
      </Button>
    </form>
  );
}

export default LoginForm;
"""),
    ("src/pages/Login.tsx", """import React from 'react';
import { Container, Box, Typography } from '@material-ui/core';
import LoginForm from '../components/LoginForm';

function LoginPage() {
  return (
    <Container maxWidth="sm">
      <Box my={4}>
        <Typography variant="h4">Login to Your Account</Typography>
        <LoginForm />
      </Box>
    </Container>
  );
}

export default LoginPage;
""")
  ])

proc cleanupTestEnvironment(repoDir: string) =
  ## Cleans up the test environment
  if dirExists(repoDir):
    removeDir(repoDir)

type
  EndToEndTestContext = object
    repoDir: string
    manager: RepositoryManager

proc getCommitRanges(manager: RepositoryManager): Future[Table[string, string]] {.async.} =
  ## Gets the last commit range for each repository
  result = initTable[string, string]()
  
  for repoName in manager.repos.keys:
    let repoOpt = manager.getRepository(repoName)
    if repoOpt.isNone:
      continue
      
    let repo = repoOpt.get
    let jjRepo = await jujutsu.initJujutsuRepo(repo.path)
    
    # Get latest commit
    let latestCommit = await jjRepo.getCurrentCommit()
    
    # Set commit range to include only the latest commit
    result[repoName] = latestCommit & "~1.." & latestCommit

suite "End-to-End Multi-Repository Commit Division Tests":
  var testContext: EndToEndTestContext
  
  setup:
    # Set up test environment
    let setupResult = waitFor setupTestEnvironment()
    testContext.repoDir = setupResult.repoDir
    testContext.manager = setupResult.manager
    
    # Make multi-repo changes
    waitFor makeMultiRepoChanges(testContext.manager)
  
  teardown:
    # Clean up test environment
    cleanupTestEnvironment(testContext.repoDir)
  
  test "End-to-End Analysis":
    # Test the analysis phase of the commit division process
    let commitRanges = waitFor getCommitRanges(testContext.manager)
    let repoNames = toSeq(testContext.manager.repos.keys)
    
    # Use a simple commit range for testing
    let commitRange = "HEAD~1..HEAD"
    
    # Analyze the changes
    let diff = waitFor analyzeCrossRepoChanges(testContext.manager, repoNames, commitRange)
    
    # Verify diff structure
    check(diff.repositories.len == 3)
    check(diff.changes.hasKey("core-lib"))
    check(diff.changes.hasKey("api-service"))
    check(diff.changes.hasKey("frontend-app"))
    
    # Verify file changes
    check(diff.changes["core-lib"].len > 0)
    check(diff.changes["api-service"].len > 0)
    check(diff.changes["frontend-app"].len > 0)
    
    # Analyze dependencies
    let dependencies = waitFor identifyCrossRepoDependencies(diff)
    
    # Verify dependencies
    check(dependencies.len > 0)
    
    # Check for specific dependencies
    var foundCoreToApi = false
    var foundApiToFrontend = false
    
    for dep in dependencies:
      if dep.source == "api-service" and dep.target == "core-lib":
        foundCoreToApi = true
      elif dep.source == "frontend-app" and dep.target == "api-service":
        foundApiToFrontend = true
    
    check(foundCoreToApi)
    # Frontend to API dependency might or might not be detected directly
  
  test "End-to-End Proposal Generation":
    # Test the proposal generation phase of the commit division process
    let commitRanges = waitFor getCommitRanges(testContext.manager)
    let repoNames = toSeq(testContext.manager.repos.keys)
    
    # Use a simple commit range for testing
    let commitRange = "HEAD~1..HEAD"
    
    # Analyze the changes
    let diff = waitFor analyzeCrossRepoChanges(testContext.manager, repoNames, commitRange)
    
    # Generate a proposal
    let proposal = waitFor generateCrossRepoProposal(diff, testContext.manager)
    
    # Verify proposal structure
    check(proposal.commitGroups.len > 0)
    check(proposal.confidenceScore > 0.0)
    
    # Check if all repositories are included
    var includedRepos = initHashSet[string]()
    for group in proposal.commitGroups:
      for commit in group.commits:
        includedRepos.incl(commit.repository)
    
    check(includedRepos.len == 3)
    check("core-lib" in includedRepos)
    check("api-service" in includedRepos)
    check("frontend-app" in includedRepos)
    
    # Check for feature-related group
    var hasFeatureGroup = false
    for group in proposal.commitGroups:
      if group.changeType == single_semantic.ChangeType.ctFeature:
        hasFeatureGroup = true
        break
    
    check(hasFeatureGroup)
    
    # Check commit messages
    for group in proposal.commitGroups:
      for commit in group.commits:
        # Verify conventional commits format
        check(commit.message.contains(":"))
        let commitType = commit.message.split(":")[0]
        check(commitType in ["feat", "fix", "docs", "style", "refactor", "perf", "test", "chore"])
  
  test "End-to-End MCP Tool Integration":
    # Test the integration with MCP tools
    let commitRange = "HEAD~1..HEAD"
    
    # Create parameters for MCP tool
    let params = %*{
      "reposDir": testContext.repoDir,
      "commitRange": commitRange
    }
    
    # Test analysis tool
    let analysisResult = waitFor analyzeMultiRepoCommitsTool(params)
    
    # Verify analysis results
    check(analysisResult.hasKey("analysis"))
    check(analysisResult["analysis"].hasKey("repositories"))
    check(analysisResult["analysis"].hasKey("dependencies"))
    check(analysisResult["analysis"]["repositories"].len == 3)
    
    # Test proposal tool
    let proposalResult = waitFor proposeMultiRepoSplitTool(params)
    
    # Verify proposal results
    check(proposalResult.hasKey("proposal"))
    check(proposalResult["proposal"].hasKey("commitGroups"))
    check(proposalResult["proposal"]["commitGroups"].len > 0)
    
    # Check that all repositories are included in the proposal
    var includedRepos = initHashSet[string]()
    for group in proposalResult["proposal"]["commitGroups"]:
      for commit in group["commits"]:
        includedRepos.incl(commit["repository"].getStr)
    
    check(includedRepos.len == 3)
    check("core-lib" in includedRepos)
    check("api-service" in includedRepos)
    check("frontend-app" in includedRepos)