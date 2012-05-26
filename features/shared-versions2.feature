Feature: Shared versions
  As a project manager 
  I want to use shared versions
  So that I can manage release over projects

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And the subproject1 project has the backlogs plugin enabled
      And I am a product owner of the project
      And no versions or issues exist

#      And I have defined the following sprints:
#        | name       | sprint_start_date | effective_date | sharing   | project_id    |
#        | Sprint 001 | 2010-01-01        | 2010-01-31     | hierarchy | ecookbook     |
#        | Sprint 002 | 2010-01-01        | 2010-01-31     | none      | ecookbook     |
#
#      And I have defined the following stories in the following sprints:
#        | position | subject | sprint     | project_id    |
#        | 1        | Story 1 | Sprint 001 | ecookbook     |
#        | 2        | Story 2 | Sprint 001 | ecookbook     |
#        | 3        | Story 3 | Sprint 002 | ecookbook     |
#
#      And I have defined the following tasks:
#        | subject | story  |
#        | Task 1  | Story 1 |
#
  Scenario: Create a story in the parent product backlog but for a child project
    Given I have selected the ecookbook project
      And I am viewing the master backlog
      And I want to create a story
      And I set the subject of the story to A Whole New Story
      And I set the project of the story to subproject1
     When I create the story
     Then the request should complete successfully
      And the 1st story in the product backlog should be A Whole New Story

  Scenario: Create a story in a child sprint
    Given I have selected the subproject1 project
     Then I see the Backlogs link in the menu
    Given I am viewing the master backlog
      And I want to create a story
      And I set the subject of the story to A Whole New Story
     When I create the story
     Then the request should complete successfully
      And show me the list of stories
      And the 1st story in the product backlog should be A Whole New Story
    Given I have selected the ecookbook project
    Given I am viewing the master backlog
     Then the 1st story in the product backlog should be A Whole New Story

  Scenario: Create a story in a parent sprint which is shared in a subproject
    Given I have selected the ecookbook project
      And I am viewing the master backlog
      And I want to create a story
      And I set the subject of the story to A Whole New Story
      And I set the project of the story to subproject1
     When I create the story on the menu of Sprint 001
     Then the request should complete successfully
      And show me the list of stories
      And the 1st story in the backlog of Sprint 001 should be A Whole New Story

  Scenario: Create a story in a parent sprint which is not shared in a subproject
    Given I have selected the ecookbook project
      And I am viewing the master backlog
      And I want to create a story
      And I set the subject of the story to A Whole New Story
      And I set the project of the story to subproject1
      And I set the project of the story to subproject1
     When I create the story on the menu of Sprint 002
     Then the request should complete successfully
      And the 1st story in the backlog of Sprint 002 should be A Whole New Story
