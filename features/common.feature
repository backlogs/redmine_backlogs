Feature: Common
  As a user
  I want to do stuff
  So that I can do my job

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a team member of the project

  Scenario: View the product backlog
    Given I am viewing the master backlog
     When I request the server_variables resource
     Then the request should complete successfully
     
  Scenario: View the product backlog without any stories
    Given there are no stories in the project
     When I view the master backlog
     Then the request should complete successfully

  Scenario: Access the plugin while no trackers are set
    Given story and task trackers for the ecookbook project are not configured
     When I view the master backlog
     Then I should see the 'not_configured' notice

  Scenario: View the master backlog without specifying a project id
     When I view the master backlog without specifying a project id
     Then the request should fail
