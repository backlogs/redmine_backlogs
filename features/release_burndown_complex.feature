Feature: Release burndown complex
  As a product owner
  I want to analyze the progress of my releases
  So that i can get a feeling for the projects progress

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And I am a product owner of the project
      And I have the following issue statuses available:
        | name        | is_closed | is_default | default_done_ratio |
        | New         |         0 |          1 |                    |
        | In Progress |         0 |          0 |                    |
        | Feedback    |         0 |          0 |                    |
        | Accepted    |         1 |          0 |                    |
        | Rejected    |         1 |          0 |                  1 |
      And the current time is 2011-01-01 08:00:00
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2011-01-01        | 2011-01-31     |
        | Sprint 002 | 2011-02-01        | 2011-02-28     |
        | Sprint 003 | 2011-03-01        | 2011-03-31     |
        | Sprint 004 | 2011-04-01        | 2011-04-30     |
        | Sprint 005 | 2011-05-01        | 2011-05-31     |
        | Sprint 006 | 2011-06-01        | 2011-06-30     |
        | Sprint 007 | 2011-07-01        | 2011-07-31     |
      And I have defined the following releases:
        | name    | project    | release_start_date | release_end_date |
        | Rel 1   | ecookbook  | 2011-01-01         | 2011-07-31       |
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story A | Rel 1   | 3 |
        | Story B | Rel 1   | 2 |
        | Story C | Rel 1   | 5 |
        | Story D | Rel 1   | 4 |
        | Story E | Rel 1   | 8 |
        | Story X | Rel 1   | 2 |
# Sprint 1
      And I move the story named Story A to the 1st position of the sprint named Sprint 001
      And I move the story named Story B to the 1st position of the sprint named Sprint 001
      And I have made the following story mutations:
        | day | story   | status   |
        | 1   | Story A | Closed   |
        | 2   | Story B | Closed   |
      And the current time is 2011-01-15 23:00:00
      And I have defined the following stories in the product backlog:
        | subject | release | points |
        | Story F | Rel 1   | 4 |
        | Story G | Rel 1   | 2 |
# Sprint 2
      And I move the story named Story C to the 1st position of the sprint named Sprint 002
      And the current time is 2011-02-01 08:00:00
      And I have made the following story mutations:
        | day | story   | status    |
        | 1   | Story C | Closed    |
# Sprint 3
      And I move the story named Story E to the 1st position of the sprint named Sprint 003
      And the current time is 2011-03-01 08:00:00
      And I duplicate Story E to release Rel 1 as Story E 2nd
      And I set story Story E 2nd release relationship to continued
      And I have made the following story mutations:
        | day | story   | status      |
        | 5   | Story E | Rejected    |
# Sprint 4
      And I move the story named Story G to the 1st position of the sprint named Sprint 004
      And the current time is 2011-04-01 08:00:00
      And I have made the following story mutations:
        | day | story   | status      |
        | 5   | Story G | Rejected    |
# Sprint 5
      And I move the story named Story X to the 1st position of the sprint named Sprint 005
      And the current time is 2011-05-01 08:00:00
    Given I am viewing the master backlog
     When I move story Story E 2nd to the product backlog
      And I have made the following story mutations:
        | day | story   | status      |
        | 5   | Story X | Closed      |
# Sprint 6
      And I move the story named Story D to the 1st position of the sprint named Sprint 006
      And the current time is 2011-06-01 08:00:00
      And I have made the following story mutations:
        | day | story   | status      |
        | 5   | Story D | Closed      |
# Sprint 7
      And I move the story named Story F to the 1st position of the sprint named Sprint 007
      And the current time is 2011-07-01 08:00:00
      And I have made the following story mutations:
        | day | story   | status      |
        | 20   | Story F | Closed      |

#FIXME Closing sprints?

   Scenario: View complete release burndown
    Given I view the release page
     Then show me the burndown data for release "Rel 1"
#     Then dump the database to pg_new.dump
      And the release burndown for release "Rel 1" should be:
        | sprint| backlog_points | closed_points | added_points |
        | start | 24             | 0         | 0     |
        | 1     | 19             | 5         | 6     |
        | 2     | 14             | 10         | 6     |
        | 3     | 14             | 10         | 6     |
        | 4     | 14             | 10         | 4     |
        | 5     |  4             | 12         | 4     |
        | 6     |  0             | 16         | 4     |
        | 7     |  0             | 20         | 0     |

   Scenario: Move stories to another release to simulate migrated project
    Given I have defined the following releases:
        | name    | project    | release_start_date | release_end_date |
        | Moved   | ecookbook  | 2011-01-01         | 2011-07-31       |
      And the current time is 2011-09-01 08:00:00
     When I move story Story A to the release Moved
     When I move story Story B to the release Moved
     When I move story Story C to the release Moved
     When I move story Story D to the release Moved
     When I move story Story E to the release Moved
     When I move story Story F to the release Moved
     When I move story Story G to the release Moved
     When I move story Story X to the release Moved
      And I set story Story A release relationship to initial
      And I set story Story B release relationship to initial
      And I set story Story C release relationship to initial
      And I set story Story D release relationship to initial
      And I set story Story E release relationship to initial
      And I set story Story X release relationship to initial
      And I set story Story F release relationship to added
      And I set story Story G release relationship to added
      And I view the release page
     Then show me the burndown data for release "Moved"
      And the release burndown for release "Moved" should be:
        | sprint| backlog_points | closed_points | added_points |
        | start | 24             | 0         | 0     |
        | 1     | 19             | 5         | 6     |
        | 2     | 14             | 10         | 6     |
# The next two backlog_points differ from the original (14=>6)
# Due to the moved stories there is no history information regarding
# Story 2nd being part of the release during sprints 3+4.
        | 3     |  6             | 10         | 6     |
        | 4     |  6             | 10         | 4     |
        | 5     |  4             | 12         | 4     |
        | 6     |  0             | 16         | 4     |
        | 7     |  0             | 20         | 0     |
