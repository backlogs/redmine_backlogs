Feature: Release multiview burnchart
  As a product owner
  I want to see progress of multiple releases
  So that I can get an overview of the project

  Background:
    Given the ecookbook project has the backlogs plugin enabled
      And no versions or issues exist
      And no releases or release multiviews exist
      And I am a product owner of the project
      And the current time is 2011-12-31 08:00:00
      And I have defined the following sprints:
        | name       | sprint_start_date | effective_date |
        | Sprint 001 | 2012-01-01        | 2012-01-31     |
        | Sprint 002 | 2012-02-01        | 2012-02-28     |
        | Sprint 003 | 2012-03-01        | 2012-03-31     |
        | Sprint 004 | 2012-04-01        | 2012-04-30     |
        | Sprint 005 | 2012-05-01        | 2012-05-31     |
        | Sprint 006 | 2012-06-01        | 2012-06-30     |
        | Sprint 007 | 2012-07-01        | 2012-07-30     |
        | Sprint 008 | 2012-08-01        | 2012-08-31     |
        | Sprint 009 | 2012-09-01        | 2012-09-30     |
        | Sprint 010 | 2012-10-01        | 2012-10-31     |
        | Sprint 011 | 2012-11-01        | 2012-11-30     |
        | Sprint 012 | 2012-12-01        | 2012-12-31     |
      And I have defined the following releases:
        | name     | project    | release_start_date | release_end_date |
        | Rel 1    | ecookbook  | 2012-01-01         | 2012-02-28       |
        | Rel 2    | ecookbook  | 2012-02-01         | 2012-06-30       |
        | Rel 3    | ecookbook  | 2012-06-01         | 2012-09-30       |
        | Rel 4    | ecookbook  | 2012-09-01         | 2012-12-31       |
      And I have defined the following release multiviews:
        | name    | project   | releases    |
        | Multi 1 | ecookbook | Rel 1,Rel 2,Rel 3,Rel 4 |
      # And I have defined the following stories in the product backlog:
      #   | subject | release | points |
      #   | Story 01 | Rel 1   | 5 |
      #   | Story 02 | Rel 1   | 5 |
      #   | Story 03 | Rel 1   | 5 |
      #   | Story 04 | Rel 1   | 5 |
      #   | Story 05 | Rel 1   | 5 |
      #   | Story 06 | Rel 2   | 5 |
      #   | Story 07 | Rel 2   | 5 |
      #   | Story 08 | Rel 2   | 5 |
      #   | Story 09 | Rel 2   | 5 |
      #   | Story 10 | Rel 2   | 5 |
      #   | Story 11 | Rel 3   | 5 |
      #   | Story 12 | Rel 3   | 5 |
      #   | Story 13 | Rel 3   | 5 |
      #   | Story 14 | Rel 3   | 5 |
      #   | Story 15 | Rel 3   | 5 |
      #   | Story 16 | Rel 4   | 5 |
      #   | Story 17 | Rel 4   | 5 |
      #   | Story 18 | Rel 4   | 5 |
      #   | Story 19 | Rel 4   | 5 |
      #   | Story 20 | Rel 4   | 5 |
      #   | Story 21 |         | 5 |
      #   | Story 22 |         | 5 |
      #   | Story 23 |         | 5 |
      #   | Story 24 |         | 5 |
      #   | Story 25 |         | 5 |
      And I have defined the following stories in the following sprints:
        | subject | sprint     | release | points |
        | Story 01 | Sprint 001 | Rel 1   | 5 |
        | Story 02 | Sprint 001 | Rel 1   | 5 |
        | Story 03 | Sprint 002 | Rel 1   | 5 |
        | Story 04 | Sprint 002 | Rel 1   | 5 |
        | Story 05 | Sprint 003 | Rel 1   | 5 |
        | Story 06 | Sprint 003 | Rel 2   | 5 |
        | Story 07 | Sprint 004 | Rel 2   | 5 |
        | Story 08 | Sprint 004 | Rel 2   | 5 |
        | Story 09 | Sprint 005 | Rel 2   | 5 |
        | Story 10 | Sprint 005 | Rel 2   | 5 |
        | Story 11 | Sprint 006 | Rel 3   | 5 |
        | Story 12 | Sprint 006 | Rel 3   | 5 |
        | Story 13 | Sprint 007 | Rel 3   | 5 |
        | Story 14 | Sprint 007 | Rel 3   | 5 |
        | Story 15 | Sprint 008 | Rel 3   | 5 |
        | Story 16 | Sprint 008 | Rel 4   | 5 |
        | Story 17 | Sprint 009 | Rel 4   | 5 |
        | Story 18 | Sprint 009 | Rel 4   | 5 |
        | Story 19 | Sprint 010 | Rel 4   | 5 |
        | Story 20 | Sprint 010	| Rel 4   | 5 |
      And I have defined the following stories in the product backlog:
        | subject  | release | points |
        | Story 21 |         | 5 |
        | Story 22 |         | 5 |
        | Story 23 |         | 5 |
        | Story 24 |         | 5 |
        | Story 25 |         | 5 |
      And the current time is 2012-01-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 01 | Closed   |
        | 10  | Story 02 | Closed   |
      And the current time is 2012-02-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 03 | Closed   |
        | 10  | Story 04 | Closed   |
      And the current time is 2012-03-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 05 | Closed   |
        | 10  | Story 06 | Closed   |
      And the current time is 2012-04-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 07 | Closed   |
        | 10  | Story 08 | Closed   |
      And the current time is 2012-05-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 09 | Closed   |
        | 10  | Story 10 | Closed   |
      And the current time is 2012-06-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 11 | Closed   |
        | 10  | Story 12 | Closed   |
      And the current time is 2012-07-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 13 | Closed   |
        | 10  | Story 14 | Closed   |
      And the current time is 2012-08-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 15 | Closed   |
        | 10  | Story 16 | Closed   |
      And the current time is 2012-09-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 17 | Closed   |
        | 10  | Story 18 | Closed   |
      And the current time is 2012-10-01 08:00:00
      And I have made the following story mutations:
        | day | story    | status   |
        | 5   | Story 19 | Closed   |
        | 10  | Story 20  | Closed   |

  Scenario: Initial
    Given I view the release page
#     Then dump the database to pg_new.dump
     When I follow "Multi 1"
     Then the request should complete successfully
     Then show me the page