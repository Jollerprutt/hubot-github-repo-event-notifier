#! /usr/bin/env coffee

#commit_comment,create,delete,deployment,deployment_status,fork,gollum,issue_comment,issues,member,membership,page_build,pull_request_review_comment,pull_request,push,repository,release,status,ping,team_add,watch

unique = (array) ->
  output = {}
  output[array[key]] = array[key] for key in [0...array.length]
  value for key, value of output

extractMentionsFromBody = (body) ->
  mentioned = body.match(/(^|\s)(@[\w\-\/]+)/g)

  if mentioned?
    mentioned = mentioned.filter (nick) ->
      slashes = nick.match(/\//g)
      slashes is null or slashes.length < 2

    mentioned = mentioned.map (nick) -> nick.trim()
    mentioned = unique mentioned

    "\nMentioned: #{mentioned.join(", ")}"
  else
    ""

formatUrl = (adapter, url, text) ->
  switch adapter
    when "gitter2"
      "[#{text}](#{url})"
    when "mattermost" || "slack"
      "<#{url}|#{text}>"
    else
      "#{text} (#{url}) adapter: #{adapter}"

module.exports =
  commit_comment: (adapter, data, callback) ->
    comment = data.comment
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    commit_link = formatUrl adapter, comment.html_url, comment.commit_id

    callback "#{repo_link} - New comment by #{comment.user.login} on commit #{commit_link}: \n\"#{comment.body}\""

  create: (adapter, data, callback) ->
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    ref_type = data.ref_type
    ref = data.ref

    callback "#{repo_link} - New #{ref_type} #{ref} created"

  delete: (adapter, data, callback) ->
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    ref_type = data.ref_type

    ref = data.ref.split('refs/heads/').join('')

    callback "#{repo_link} - #{ref_type} #{ref} deleted"

  deployment: (adapter, data, callback) ->
    deploy = data.deployment
    repo = data.repository

    callback "New deployment #{deploy.id} from: #{repo.full_name} to: #{deploy.environment} started by: #{deploy.creator.login}"

  deployment_status: (adapter, data, callback) ->
    deploy = data.deployment
    deploy_status = data.deployment_status
    repo = data.repository

    callback "Deployment #{deploy.id} from: #{repo.full_name} to: #{deploy.environment} - #{deploy_status.state} by #{deploy.status.creator.login}"

  fork: (adapter, data, callback) ->
    forkee = data.forkee
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name

    callback "#{repo_link} forked by #{forkee.owner.login}"

  # Needs to handle more then just one page
  gollum: (adapter, data, callback) ->
    pages = data.pages
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    sender = data.sender

    page = pages[0]

    callback "#{repo_link} - Wiki page #{page.page_name} (#{page.html_url}) #{page.action} by #{sender.login}"

  issues: (adapter, data, callback) ->
    issue = data.issue
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    issue_link = formatUrl adapter, issue.html_url, "##{issue.number} \"#{issue.title}\""
    action = data.action
    sender = data.sender
    issue_by = formatUrl adapter, sender.html_url, sender.login
    issue_for = formatUrl adapter, sender.html_url, issue.assignee.login

    msg = "#{repo_link} - Issue #{issue_link}"

    switch action
      when "assigned"
        if issue.assignee.login is sender.login
          msg += " self-assigned by #{issue_for} "
        else
          msg += " assigned to: #{issue_for} by #{issue_by} "
      when "unassigned"
        msg += " unassigned #{data.assignee.login} by #{issue_by} "
      when "opened"
        msg += " opened by #{issue_by} "
      when "closed"
        msg += " closed by #{issue_by} "
      when "reopened"
        msg += " reopened by #{issue_by} "
      when "labeled"
        msg += " #{issue_by} added label: \"#{data.label.name}\" "
      when "unlabeled"
        msg += " #{issue_by} removed label: \"#{data.label.name}\" "

    callback msg

  issue_comment: (adapter, data, callback) ->
    issue = data.issue
    comment = data.comment
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name

    issue_pull = "Issue"

    if comment.html_url.indexOf("/pull/") > -1
      issue_pull = "Pull Request"

    comment_link = formatUrl adapter, comment.html_url, "#{issue_pull} ##{issue.number}"
    callback "#{repo_link} - New comment on #{comment_link} by #{comment.user.login}: \n\"#{comment.body}\""

  member: (adapter, data, callback) ->
    member = data.member
    repo = data.repository

    callback "Member #{member.login} #{data.action} from #{repo.full_name}"

  # Org level event
  membership: (adapter, data, callback) ->
    scope = data.scope
    member = data.member
    team = data.team
    org = data.organization

    callback "#{org.login} #{data.action} #{member.login} to #{scope} #{team.name}"

  page_build: (adapter, data, callback) ->
    build = data.build
    repo = data.repository
    if build?
      if build.status is "built"
        callback "#{build.pusher.login} built #{data.repository.full_name} pages at #{build.commit} in #{build.duration}ms."
      if build.error.message?
        callback "Page build for #{data.repository.full_name} errored: #{build.error.message}."

  pull_request_review_comment: (adapter, data, callback) ->
    comment = data.comment
    pull_req = data.pull_request
    base = data.base
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    comment_link = formatUrl adapter, comment.html_url, pull_req.title

    callback "#{repo_link} - New comment on Pull Request #{comment_link} by #{comment.user.login}: \n\"#{comment.body}\""

  pull_request: (adapter, data, callback) ->
    pull_num = data.number
    pull_req = data.pull_request
    base = data.base
    repo = data.repository
    sender = data.sender
    repo_link = formatUrl adapter, repo.html_url, repo.name
    pull_request_link = formatUrl adapter, pull_req.html_url, "##{data.number} \"#{pull_req.title}\""
    pull_by = formatUrl adapter, sender.html_url, sender.login

    action = data.action

    msg = "#{repo_link} - Pull Request #{pull_request_link}"

    switch action
      when "assigned"
        msg += " assigned to: #{data.assignee.login} by #{pull_by} "
      when "unassigned"
        msg += " unassigned #{data.assignee.login} by #{pull_by} "
      when "review_requested"
        msg += " review requested from "
        reviewers = data.pull_request.requested_reviewers
        if reviewers.length == 1
          msg += "@#{data.requested_reviewer.login} "
        else if reviewers.length > 1
          for review in reviewers
            msg += "@#{review.login} "
        msg += "by #{pull_by} "
      when "opened"
        msg += " opened by #{pull_by} "
      when "closed"
        if pull_req.merged
          msg += " merged by #{pull_by} "
        else
          msg += " closed by #{pull_by} "
      when "reopened"
        msg += " reopened by #{pull_by} "
      when "labeled"
        msg += " #{pull_by} added label: \"#{data.label.name}\" "
      when "unlabeled"
        msg += " #{pull_by} removed label: \"#{data.label.name}\" "
      when "synchronize"
        msg +=" synchronized by #{pull_by} "

    callback msg

  push: (adapter, data, callback) ->
    commit = data.after
    commits = data.commits
    head_commit = data.head_commit
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    pusher = data.pusher

    if !data.deleted
      if commits.length == 1
        commit_link = formatUrl adapter, head_commit.url, "commit"
        callback "#{repo_link} - New commit by #{pusher.name}\n#{commit_link}: #{head_commit.message}"
      else if commits.length > 1
        num = 1
        message = "#{repo_link} - #{pusher.name} pushed #{commits.length} commits:"
        for commit in commits
          commit_link = formatUrl adapter, commit.url, "##{num++}"
          message += "\n#{commit_link}: #{commit.message}"
        callback message

  # Org level event
  repository: (adapter, data, callback) ->
    repo = data.repository
    org = data.organization
    action = data.action
    repo_link = formatUrl adapter, repo.html_url, repo.full_name

    callback "#{repo_link} #{action}"

  release: (adapter, data, callback) ->
    release = data.release
    repo = data.repository
    repo_link = formatUrl adapter, repo.html_url, repo.name
    action = data.action

    callback "#{repo_link} - Release #{release.tag_name} #{action}"

  # No clue what to do with this one.
  status: (adapter, data, callback) ->
    commit = data.commit
    state = data.state
    branches = data.branches
    repo = data.repository

    callback ""

  ping: (adapter, data, callback) ->
    hook_id = data.hook_id
    sender = data.sender
    ping_by = formatUrl adapter, sender.html_url, sender.login

    callback "ping by #{ping_by}. hook_id: #{hook_id}"

  watch: (adapter, data, callback) ->
    repo = data.repository
    sender = data.sender

    callback "#{repo.full_name} is now being watched by #{sender.login}"
