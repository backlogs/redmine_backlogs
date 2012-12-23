Feature: Duplicate story
  As a member
  I want be able to duplicate a story 
  So that I can split a story or continue work in another sprint

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
        | Sprint 004 | 2010-04-01        | 2010-04-30     |
      And I have defined the following stories in the following sprints:
        | subject | sprint     |
        | Story 1 | Sprint 001 |
      And I have defined the following tasks:
        | subject | story   |
        | Task 1  | Story 1 |
        | Task 2  | Story 1 |

  Scenario: Duplicate story without tasks
    Given I am duplicating Story 1 to Story 1A for Sprint 002
      And I choose to copy none tasks
    When I click copy
      Then the request should complete successfully
      And sprint Sprint 002 should contain Story 1A

  #using javascript to disable redmine2.1 copy_subtasks button
  @javascript
  Scenario: Duplicate story with tasks
    Given I am duplicating Story 1 to Story 1B for Sprint 003
      And I choose to copy open tasks
    When I click copy
      Then the request should complete successfully
      And sprint Sprint 003 should contain Story 1B
      And the story named Story 1B should have a task named Task 1
      And the story named Story 1B should have a task named Task 2

#  Scenario: Duplicate story with some tasks closed

