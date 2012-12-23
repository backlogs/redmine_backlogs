Feature: Extended timelog
  As a member
  I want to update spent time and remaining hours easily
  So that I can update everyone on the status of the project

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And timelog from taskboard has been enabled
      And I am a team member of the project and allowed to update remaining hours
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
      And I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story 1 | Sprint 001 |
      And I have defined the following tasks:
        | subject | story  |
        | Task 1  | Story 1 |
        
  Scenario: Log time and set remaining hours from "Log time"-view
    Given I am logging time for task Task 1
      And I set the hours spent to 2
      And I set the remaining_hours to 5
    When I click save
      Then the request should complete successfully
      And task Task 1 should have remaining_hours set to 5
      And task Task 1 should have a total time spent of 2 hours

  Scenario: Log time from "Log Time"-view without selecting task
    Given I am viewing log time for the ecookbook project
      And I set the hours spent to 2
    When I click save
      Then the request should complete successfully
