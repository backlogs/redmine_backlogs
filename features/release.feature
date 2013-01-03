Feature: Release functionality
  As a scrum master
  I want to manage what goes into a release and how it's progressing
  So that I can update everyone on the status of the project

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And I am a scrum master of the project
      And I have deleted all existing issues
      And I have defined the following releases:
        | name        | sprints                            | 
        | Version 1.0 | Sprint 001, Sprint 002, Sprint 003 |
        | Version 2.0 | Sprint 004, Sprint 005, Sprint 006 |
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2010-01-01        | 2010-01-31     |
        | Sprint 002 | 2010-02-01        | 2010-02-28     |
        | Sprint 003 | 2010-03-01        | 2010-03-31     |
        | Sprint 004 | 2010-04-01        | 2010-04-30     |
        | Sprint 005 | 2010-05-01        | 2010-05-31     |
        | Sprint 006 | 2010-06-01        | 2010-06-31     |
      And I have defined the following stories in the following sprints:
        | position | subject | sprint     | story_points |
        | 1        | Story A | Sprint 001 | 2            |
        | 2        | Story B | Sprint 001 | 4            |
        | 1        | Story C | Sprint 002 | 2            |
        | 2        | Story D | Sprint 002 | 4            |
        | 1        | Story E | Sprint 003 | 2            |
        | 2        | Story F | Sprint 003 | 4            |
        | 1        | Story G | Sprint 004 | 2            |
        | 2        | Story H | Sprint 004 | 4            |
        | 1        | Story I | Sprint 005 | 2            |
        | 2        | Story J | Sprint 005 | 4            |
        | 1        | Story K | Sprint 006 | 2            |
        | 2        | Story L | Sprint 006 | 4            |

  Scenario: Show release backlogs along with general product backlog on the backlog view
    Given I am viewing the master backlog
     Then I should see "Version 1.0"
      And I should see "Version 2.0"
      And I should see "Product backlog"

  Scenario: View release graph for Version 1.0 after 1 sprint
    Given I complete Sprint 001
     When I fetch CSV output of the release graph for Version 1.0
      Then the Sprint 1 column should show 6 points completed and 12 points remaining
     
  Scenario: Add story to release backlog
    Given I complete Sprint 001
      And I add story Story C1 of 3 points to release Version 1.0
      And I complete Sprint 002
     When I fetch CSV output of the release graph for Version 1.0
     Then the Sprint 001 column should show 6 points completed and 12 points remaining
      And the Sprint 002 column should show 6 points completed and 6 points remaining and 3 points added
      And the gradient for added points at Sprint 002 should be -3 points
      And the gradient for remaining points at Sprint 002 should be -6 points

  Scenario: Remove story from release backlog

