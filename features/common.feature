Feature: Common
  As a user
  I want to do stuff
  So that I can do my job

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a team member of the project
      And sharing is not enabled

  Scenario: View the product backlog
    Given I am viewing the master backlog
     When I request the server_variables resource
     Then the request should complete successfully
     
  Scenario: View the product backlog
    Given I am viewing the master backlog
      And sharing is enabled
     When I request the server_variables resource
     Then the request should complete successfully
     
  Scenario: View the product backlog without any stories
    Given there are no stories in the project
     When I view the master backlog
     Then the request should complete successfully
